#!/bin/bash

# Change current working directory to the base folder of this project.
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."

# Check version of Python available in PATH.
python_version=$(python -c "import sys; print(sys.version)")
python_version=( ${python_version//./ } )
if (( ${python_version[0]} == 3 )) && (( ${python_version[1]} < 11 )) || (( ${python_version[0]} < 3 )); then
  echo "Error: Python >=3.11 either not intalled, or in PATH behind an older version."
  exit 10001
fi

if [[ $# -eq 0 ]]; then
  # If this script was called without parameters use cmake_menu.py to select
  # the list of config files to use.
  TEMP_ARGUMENTS_FILE=$(mktemp)
  python scripts/cmake_menu.py "${TEMP_ARGUMENTS_FILE}" || exit 0
  readarray -t CONFIG_FILES < "${TEMP_ARGUMENTS_FILE}"
  [[ -e "${TEMP_ARGUMENTS_FILE}" ]] && rm "${TEMP_ARGUMENTS_FILE}"
else
  CONFIG_FILES=( "$@" )
fi

# Read all config files and query several specific settings that are needed
# early in this setup script.
PYTHON_PACKAGES_PATH=$(python scripts/query_config.py -q python-packages-path "${CONFIG_FILES[@]}")
if [[ ! -d "${PYTHON_PACKAGES_PATH}" ]]; then
  echo "Error: Path to Python packages does not exist '${PYTHON_PACKAGES_PATH}'"
  exit 10003
fi
VENV_PATH=$(pwd)/scripts/.venv
if [[ ! -d "${VENV_PATH}" ]]; then
  python -m venv "${VENV_PATH}"
fi
echo "* Entering Python virtual environment..."
source ${VENV_PATH}/bin/activate
echo "* Installing required Python modules..."
python -m pip install --upgrade pip
python -m pip install -r scripts/python_requirements.txt
# ToDo: Download packages to allow offline installation.
# python -m pip install --no-index --find-links "${PYTHON_PACKAGES_PATH}" -r scripts/python_requirements.txt

python scripts/cmake.py "${CONFIG_FILES[@]}"
