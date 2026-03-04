#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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

run_case_worker() {
	local case_name="$1"
	local dockerfile="$2"
	local expected_status="$3"
	local expected_pattern="$4"
	local case_dir="$5"
	local image_tag="mydotfiles-test-${case_name}-$(date +%s)-$RANDOM"
	local build_log="${case_dir}/build.log"
	local run_log="${case_dir}/run.log"
	local result_file="${case_dir}/result.env"
	local run_status=0
	local outcome="pass"
	local reason=""

	: >"$build_log"
	: >"$run_log"

	set +e
	docker build -f "${SCRIPT_DIR}/${dockerfile}" -t "${image_tag}" "${REPO_ROOT}" >"$build_log" 2>&1
	local build_status=$?
	set -e

	if [ "$build_status" -ne 0 ]; then
		outcome="fail"
		reason="build_failed"
	else
		set +e
		docker run --rm "${image_tag}" >"$run_log" 2>&1
		run_status=$?
		set -e

		if [ "$expected_status" = "0" ] && [ "$run_status" -ne 0 ]; then
			outcome="fail"
			reason="unexpected_nonzero_exit"
		elif [ "$expected_status" = "nonzero" ] && [ "$run_status" -eq 0 ]; then
			outcome="fail"
			reason="expected_nonzero_exit"
		elif [ -n "$expected_pattern" ] && ! grep -Fq "$expected_pattern" "$run_log"; then
			outcome="fail"
			reason="missing_expected_pattern"
		fi
	fi

	if [ "$cleanup_images" = true ]; then
		docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
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

CASE_NAMES=("case1-sudo-granted" "case2-no-sudo-missing" "case3-no-sudo-preinstalled")
CASE_DOCKERFILES=("Dockerfile.case1-sudo-granted" "Dockerfile.case2-no-sudo-missing" "Dockerfile.case3-no-sudo-preinstalled")
CASE_EXPECTED_STATUS=("0" "nonzero" "0")
CASE_EXPECTED_PATTERNS=("POST_INSTALL_SMOKE_OK" "Missing essential commands/prerequisites" "POST_INSTALL_SMOKE_OK")

MAX_PARALLEL_CASES="${MAX_PARALLEL_CASES:-2}"
if ! [[ "$MAX_PARALLEL_CASES" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLEL_CASES" -lt 1 ]; then
	echo "MAX_PARALLEL_CASES must be a positive integer."
	exit 1
fi

tmp_root="$(mktemp -d /tmp/mydotfiles-tests.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

declare -a case_pids case_dirs

start_case() {
	local idx="$1"
	local case_dir="${tmp_root}/${CASE_NAMES[$idx]}"
	mkdir -p "$case_dir"
	case_dirs[$idx]="$case_dir"
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

total_cases="${#CASE_NAMES[@]}"
next_to_start=0
running=0
unexpected_worker_failure=false
while [ "$next_to_start" -lt "$total_cases" ] || [ "$running" -gt 0 ]; do
	while [ "$running" -lt "$MAX_PARALLEL_CASES" ] && [ "$next_to_start" -lt "$total_cases" ]; do
		start_case "$next_to_start"
		next_to_start=$((next_to_start + 1))
		running=$((running + 1))
	done

	if [ "$running" -gt 0 ]; then
		if ! wait -n; then
			unexpected_worker_failure=true
		fi
		running=$((running - 1))
	fi
done

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
