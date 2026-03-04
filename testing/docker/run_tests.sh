#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CASE_NAMES=("case1-sudo-granted" "case2-no-sudo-missing" "case3-no-sudo-preinstalled")
CASE_DOCKERFILES=("Dockerfile.case1-sudo-granted" "Dockerfile.case2-no-sudo-missing" "Dockerfile.case3-no-sudo-preinstalled")
CASE_EXPECTED_STATUS=("0" "nonzero" "0")
CASE_EXPECTED_PATTERNS=("POST_INSTALL_SMOKE_OK" "Missing essential commands/prerequisites" "POST_INSTALL_SMOKE_OK")

cleanup_images=true
if [ "${1:-}" = "--keep-images" ]; then
	cleanup_images=false
elif [ "${1:-}" != "" ]; then
	echo "Usage: bash testing/docker/run_tests.sh [--keep-images]"
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "Docker is not installed. Testing could not be run without Docker."
	exit 1
fi

if ! docker info >/dev/null 2>&1; then
	echo "Docker daemon is not available. Testing could not be run without Docker."
	exit 1
fi

dashboard_enabled=false
if [ -t 1 ]; then
	dashboard_enabled=true
fi

dashboard_refresh_seconds="${LOG_DASHBOARD_REFRESH_SECONDS:-1}"
if ! [[ "$dashboard_refresh_seconds" =~ ^[0-9]+$ ]] || [ "$dashboard_refresh_seconds" -lt 1 ]; then
	dashboard_refresh_seconds=1
fi

case_log_lines_per_case="${CASE_LOG_LINES_PER_CASE:-12}"
if ! [[ "$case_log_lines_per_case" =~ ^[0-9]+$ ]] || [ "$case_log_lines_per_case" -lt 1 ]; then
	case_log_lines_per_case=12
fi
effective_case_log_lines_per_case="$case_log_lines_per_case"
dashboard_terminal_prepared=false
dashboard_max_text_cols=120

clear_screen() {
	if [ "$dashboard_enabled" = true ]; then
		printf '\033[H\033[2J'
	fi
}

disable_line_wrap() {
	if [ "$dashboard_enabled" = true ]; then
		printf '\033[?7l'
	fi
}

enable_line_wrap() {
	if [ "$dashboard_enabled" = true ]; then
		printf '\033[?7h'
	fi
}

prepare_dashboard_terminal() {
	[ "$dashboard_enabled" = true ] || return
	[ "$dashboard_terminal_prepared" = true ] && return

	printf '\033[?1049h'
	printf '\033[?25l'
	disable_line_wrap
	dashboard_terminal_prepared=true
}

restore_dashboard_terminal() {
	[ "$dashboard_enabled" = true ] || return
	[ "$dashboard_terminal_prepared" = true ] || return

	enable_line_wrap
	printf '\033[?25h'
	printf '\033[?1049l'
	dashboard_terminal_prepared=false
}

sanitize_dashboard_line() {
	local line="$1"

	line="${line//$'\r'/}"
	line="$(printf '%s' "$line" | sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g; s/\x1B\\][^\a]*(\a|\x1B\\\\)//g')"
	line="$(printf '%s' "$line" | tr -d '\000-\010\013\014\016-\037\177')"
	printf '%s' "$line"
}

stage_label() {
	case "$1" in
	pending)
		printf 'pending'
		;;
	building)
		printf 'building'
		;;
	running)
		printf 'running'
		;;
	complete-pass)
		printf 'passed'
		;;
	complete-fail)
		printf 'failed'
		;;
	worker-error)
		printf 'worker error'
		;;
	*)
		printf '%s' "$1"
		;;
	esac
}

run_case_worker() {
	local case_name="$1"
	local dockerfile="$2"
	local expected_status="$3"
	local expected_pattern="$4"
	local case_dir="$5"
	local image_tag="mydotfiles-test-${case_name}-$(date +%s)-$RANDOM"
	local container_name="${image_tag}-ctr"
	local build_log="${case_dir}/build.log"
	local run_log="${case_dir}/run.log"
	local live_log="${case_dir}/live.log"
	local stage_file="${case_dir}/stage"
	local result_file="${case_dir}/result.env"
	local run_status="0"
	local outcome="pass"
	local reason=""
	local wait_output=""

	: >"$build_log"
	: >"$run_log"
	: >"$live_log"
	printf 'building\n' >"$stage_file"

	set +e
	docker build --progress=plain -f "${SCRIPT_DIR}/${dockerfile}" -t "${image_tag}" "${REPO_ROOT}" 2>&1 | tee -a "$build_log" "$live_log" >/dev/null
	local build_status=${PIPESTATUS[0]}
	set -e

	if [ "$build_status" -ne 0 ]; then
		outcome="fail"
		reason="build_failed"
	else
		printf 'running\n' >"$stage_file"

		set +e
		docker create --name "$container_name" "${image_tag}" >/dev/null 2>>"$live_log"
		local create_status=$?
		set -e
		if [ "$create_status" -ne 0 ]; then
			outcome="fail"
			reason="container_create_failed"
		else
			set +e
			docker start "$container_name" >/dev/null 2>>"$live_log"
			local start_status=$?
			if [ "$start_status" -ne 0 ]; then
				outcome="fail"
				reason="container_start_failed"
			else
				docker logs -f "$container_name" 2>&1 | tee -a "$run_log" "$live_log" >/dev/null &
				local logs_pid=$!

				wait_output="$(docker wait "$container_name" 2>>"$live_log")"
				local wait_status=$?
				if [ "$wait_status" -ne 0 ]; then
					outcome="fail"
					reason="container_wait_failed"
					run_status="unknown"
				else
					run_status="$(printf '%s' "$wait_output" | tail -n1 | tr -d '\r')"
				fi

				wait "$logs_pid" >/dev/null 2>&1 || true
			fi
			set -e

			docker rm -f "$container_name" >/dev/null 2>&1 || true
		fi

		if [ "$outcome" = "pass" ]; then
			if [ "$expected_status" = "0" ] && [ "$run_status" != "0" ]; then
				outcome="fail"
				reason="unexpected_nonzero_exit"
			elif [ "$expected_status" = "nonzero" ] && [ "$run_status" = "0" ]; then
				outcome="fail"
				reason="expected_nonzero_exit"
			elif [ -n "$expected_pattern" ] && ! grep -Fq "$expected_pattern" "$run_log"; then
				outcome="fail"
				reason="missing_expected_pattern"
			fi
		fi
	fi

	if [ "$cleanup_images" = true ]; then
		docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
	fi

	if [ "$outcome" = "pass" ]; then
		printf 'complete-pass\n' >"$stage_file"
	else
		printf 'complete-fail\n' >"$stage_file"
	fi

	{
		printf 'outcome=%q\n' "$outcome"
		printf 'reason=%q\n' "$reason"
		printf 'run_status=%q\n' "$run_status"
		printf 'expected_status=%q\n' "$expected_status"
		printf 'expected_pattern=%q\n' "$expected_pattern"
	} >"$result_file"
}

print_case_result() {
	local case_name="$1"
	local dockerfile="$2"
	local case_dir="$3"
	local build_log="${case_dir}/build.log"
	local run_log="${case_dir}/run.log"
	local live_log="${case_dir}/live.log"
	local result_file="${case_dir}/result.env"

	# shellcheck source=/dev/null
	source "$result_file"

	echo ""
	echo "=== ${case_name} ==="
	echo "Building ${dockerfile}..."

	if [ "$outcome" = "pass" ]; then
		echo "Recent logs:"
		tail -n 40 "$run_log"
		echo "Case ${case_name} passed."
		return 0
	fi

	case "$reason" in
	build_failed)
		echo "Case ${case_name} failed: docker build failed."
		echo "Recent build logs:"
		tail -n 200 "$build_log"
		;;
	container_create_failed)
		echo "Case ${case_name} failed: container creation failed."
		echo "Recent logs:"
		tail -n 200 "$live_log"
		;;
	container_start_failed)
		echo "Case ${case_name} failed: container start failed."
		echo "Recent logs:"
		tail -n 200 "$live_log"
		;;
	container_wait_failed)
		echo "Case ${case_name} failed: failed while waiting for container completion."
		echo "Recent logs:"
		tail -n 200 "$live_log"
		;;
	unexpected_nonzero_exit)
		echo "Case ${case_name} failed: expected exit code 0, got ${run_status}."
		echo "Recent logs:"
		tail -n 200 "$run_log"
		;;
	expected_nonzero_exit)
		echo "Case ${case_name} failed: expected a non-zero exit code."
		echo "Recent logs:"
		tail -n 200 "$run_log"
		;;
	missing_expected_pattern)
		echo "Case ${case_name} failed: expected output to contain '${expected_pattern}'."
		echo "Recent logs:"
		tail -n 200 "$run_log"
		;;
	*)
		echo "Case ${case_name} failed: unknown failure reason (${reason})."
		echo "Recent logs:"
		tail -n 200 "$run_log"
		;;
	esac

	return 1
}

MAX_PARALLEL_CASES="${MAX_PARALLEL_CASES:-2}"
if ! [[ "$MAX_PARALLEL_CASES" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLEL_CASES" -lt 1 ]; then
	echo "MAX_PARALLEL_CASES must be a positive integer."
	exit 1
fi

tmp_root="$(mktemp -d /tmp/mydotfiles-tests.XXXXXX)"

declare -a case_pids case_dirs

total_cases="${#CASE_NAMES[@]}"
for i in "${!CASE_NAMES[@]}"; do
	case_dirs[$i]="${tmp_root}/${CASE_NAMES[$i]}"
	mkdir -p "${case_dirs[$i]}"
	printf 'pending\n' >"${case_dirs[$i]}/stage"
	: >"${case_dirs[$i]}/live.log"
done

start_case() {
	local idx="$1"
	local case_dir="${case_dirs[$idx]}"
	run_case_worker "${CASE_NAMES[$idx]}" "${CASE_DOCKERFILES[$idx]}" "${CASE_EXPECTED_STATUS[$idx]}" "${CASE_EXPECTED_PATTERNS[$idx]}" "$case_dir" &
	case_pids[$idx]=$!
}

stop_running_cases() {
	for pid in "${case_pids[@]}"; do
		if [ -n "${pid:-}" ] && kill -0 "$pid" >/dev/null 2>&1; then
			kill "$pid" >/dev/null 2>&1 || true
		fi
	done
	for pid in "${case_pids[@]}"; do
		if [ -n "${pid:-}" ]; then
			wait "$pid" >/dev/null 2>&1 || true
		fi
	done
}

render_live_dashboard() {
	[ "$dashboard_enabled" = true ] || return

	printf '\033[H\033[J'
	echo "Docker test logs (live dashboard)"
	echo "Refresh: ${dashboard_refresh_seconds}s | Running: ${running} | Completed: ${completed_cases}/${total_cases}"
	echo "Per-case log lines: ${effective_case_log_lines_per_case} (older lines are discarded from view)."
	echo "Press Ctrl+C to stop."
	echo ""

	for i in "${!CASE_NAMES[@]}"; do
		local case_dir="${case_dirs[$i]}"
		local stage_file="${case_dir}/stage"
		local live_log="${case_dir}/live.log"
		local stage="pending"
		local visible_lines=0
		local -a log_lines=()
		if [ -f "$stage_file" ]; then
			stage="$(<"$stage_file")"
		fi

		echo "=== ${CASE_NAMES[$i]} [$(stage_label "$stage")] ==="
		if [ -s "$live_log" ]; then
			mapfile -t log_lines < <(tail -n "$effective_case_log_lines_per_case" "$live_log")
			visible_lines="${#log_lines[@]}"
			for line in "${log_lines[@]}"; do
				line="$(sanitize_dashboard_line "$line")"
				if [ "${#line}" -gt "$dashboard_max_text_cols" ]; then
					line="${line:0:$dashboard_max_text_cols}"
				fi
				printf '%s\n' "$line"
			done
		else
			echo "(no logs yet)"
			visible_lines=1
		fi
		while [ "$visible_lines" -lt "$effective_case_log_lines_per_case" ]; do
			echo ""
			visible_lines=$((visible_lines + 1))
		done
		echo ""
	done
}

handle_interrupt() {
	echo ""
	echo "Interrupted. Stopping running cases..."
	stop_running_cases
	restore_dashboard_terminal
	clear_screen
	exit 130
}

cleanup_tmp() {
	restore_dashboard_terminal
	rm -rf "$tmp_root"
}

trap 'cleanup_tmp' EXIT
trap 'handle_interrupt' INT TERM

next_to_start=0
running=0
completed_cases=0
unexpected_worker_failure=false
if [ "$dashboard_enabled" = true ] && command -v tput >/dev/null 2>&1; then
	term_lines="$(tput lines 2>/dev/null || printf '40')"
	term_cols="$(tput cols 2>/dev/null || printf '120')"
	if [[ "$term_cols" =~ ^[0-9]+$ ]] && [ "$term_cols" -gt 2 ]; then
		dashboard_max_text_cols=$((term_cols - 1))
	fi
	if [[ "$term_lines" =~ ^[0-9]+$ ]]; then
		dashboard_header_lines=5
		max_case_lines=$(( (term_lines - dashboard_header_lines) / total_cases - 2 ))
		if [ "$max_case_lines" -lt 1 ]; then
			max_case_lines=1
		fi
		if [ "$effective_case_log_lines_per_case" -gt "$max_case_lines" ]; then
			effective_case_log_lines_per_case="$max_case_lines"
		fi
	fi
fi
prepare_dashboard_terminal
while [ "$next_to_start" -lt "$total_cases" ] || [ "$running" -gt 0 ]; do
	while [ "$running" -lt "$MAX_PARALLEL_CASES" ] && [ "$next_to_start" -lt "$total_cases" ]; do
		start_case "$next_to_start"
		next_to_start=$((next_to_start + 1))
		running=$((running + 1))
	done

	if [ "$running" -gt 0 ]; then
		render_live_dashboard
		sleep "$dashboard_refresh_seconds"
	fi

	running=0
	for i in "${!CASE_NAMES[@]}"; do
		pid="${case_pids[$i]:-}"
		if [ -z "$pid" ]; then
			continue
		fi

		if kill -0 "$pid" >/dev/null 2>&1; then
			running=$((running + 1))
			continue
		fi

		set +e
		wait "$pid"
		worker_status=$?
		set -e
		if [ "$worker_status" -ne 0 ]; then
			unexpected_worker_failure=true
			printf 'worker-error\n' >"${case_dirs[$i]}/stage"
		fi
		case_pids[$i]=""
		completed_cases=$((completed_cases + 1))
	done
done

restore_dashboard_terminal
clear_screen

if [ "$unexpected_worker_failure" = true ]; then
	echo ""
	echo "One or more cases failed unexpectedly during worker execution."
	stop_running_cases
	exit 1
fi

for i in "${!CASE_NAMES[@]}"; do
	if ! print_case_result "${CASE_NAMES[$i]}" "${CASE_DOCKERFILES[$i]}" "${case_dirs[$i]}"; then
		exit 1
	fi
done

echo ""
echo "All Docker scenario tests passed."
