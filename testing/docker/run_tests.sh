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

run_case() {
	local case_name="$1"
	local dockerfile="$2"
	local expected_status="$3"
	local expected_pattern="$4"
	local image_tag="mydotfiles-test-${case_name}-$(date +%s)-$RANDOM"
	local log_file
	local status

	echo ""
	echo "=== ${case_name} ==="
	echo "Building ${dockerfile}..."
	docker build -f "${SCRIPT_DIR}/${dockerfile}" -t "${image_tag}" "${REPO_ROOT}" >/dev/null

	log_file="$(mktemp "/tmp/${case_name}.XXXXXX.log")"
	set +e
	docker run --rm "${image_tag}" >"$log_file" 2>&1
	status=$?
	set -e

	if [ "$expected_status" = "0" ] && [ "$status" -ne 0 ]; then
		echo "Case ${case_name} failed: expected exit code 0, got ${status}."
		echo "Recent logs:"
		tail -n 200 "$log_file"
		rm -f "$log_file"
		if [ "$cleanup_images" = true ]; then
			docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
		fi
		exit 1
	fi

	if [ "$expected_status" = "nonzero" ] && [ "$status" -eq 0 ]; then
		echo "Case ${case_name} failed: expected a non-zero exit code."
		echo "Recent logs:"
		tail -n 200 "$log_file"
		rm -f "$log_file"
		if [ "$cleanup_images" = true ]; then
			docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
		fi
		exit 1
	fi

	if [ -n "$expected_pattern" ] && ! grep -Fq "$expected_pattern" "$log_file"; then
		echo "Case ${case_name} failed: expected output to contain '${expected_pattern}'."
		echo "Recent logs:"
		tail -n 200 "$log_file"
		rm -f "$log_file"
		if [ "$cleanup_images" = true ]; then
			docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
		fi
		exit 1
	fi

	echo "Recent logs:"
	tail -n 40 "$log_file"
	rm -f "$log_file"
	echo "Case ${case_name} passed."

	if [ "$cleanup_images" = true ]; then
		docker image rm -f "${image_tag}" >/dev/null 2>&1 || true
	fi
}

run_case "case1-sudo-granted" "Dockerfile.case1-sudo-granted" "0" "POST_INSTALL_SMOKE_OK"
run_case "case2-no-sudo-missing" "Dockerfile.case2-no-sudo-missing" "nonzero" "Missing essential commands/prerequisites"
run_case "case3-no-sudo-preinstalled" "Dockerfile.case3-no-sudo-preinstalled" "0" "POST_INSTALL_SMOKE_OK"

echo ""
echo "All Docker scenario tests passed."
