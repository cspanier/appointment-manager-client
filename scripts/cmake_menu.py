#!/usr/bin/env python

import argparse
import glob
import json
import os
from pathlib import Path

parser = argparse.ArgumentParser(
    description='Let the user interactively select CMake options.')
parser.add_argument('results_filename',
                    help='Full path to a file where to write the list of selected options.')
args = parser.parse_args()

settings_filename = 'scripts/.cmake_menu.json'
# Try to load previous settings from file.
try:
    with open(settings_filename, "r") as settings_file:
        settings = json.load(settings_file)
except Exception:
    settings = {}
    pass

config_filenames = []
for filename in sorted(glob.glob("scripts/config-*.json")):
    config_filename = os.path.basename(filename)
    config_filenames += [(config_filename, (config_filename in settings and settings[config_filename]) or
                          len(config_filenames) == 0)]

while True:
    os.system('cls' if os.name=='nt' else 'clear')
    for index, (filename, is_selected) in enumerate(config_filenames):
        print(f'{index+1:>3}: [{"✓" if is_selected else " "}] {filename}')
    print('  c: execute CMake')
    print('  q: quit script')
    choice = input("Enter your choice: ")
    
    try:
        index = int(choice)
        if index > 0 and index <= len(config_filenames):
            filename, is_selected = config_filenames[index - 1]
            config_filenames[index - 1] = (filename, not is_selected)
    except ValueError:
        pass
    if choice == 'c':
        settings = {}
        # We have to use a temporary file to pass results back to the calling script.
        with open(args.results_filename, 'w') as file:
            for (filename, is_selected) in config_filenames:
                settings[filename] = is_selected
                if is_selected:
                    file.write(f'{filename}\n')
        # Try to save selected settings to file.
        try:
            with open(settings_filename, "w") as settings_file:
                json.dump(settings, settings_file, indent=4)
        except Exception:
            pass
        exit(0)
    elif choice == 'q':
        exit(1)
