#!/usr/bin/env python

import argparse
import collections.abc
import json
from pathlib import Path

scripts_path = Path(__file__).parent.absolute()

def update_config(old_config, new_config):
    for key, new_value in new_config.items():
        if isinstance(new_value, collections.abc.Mapping):
            old_config[key] = update_config(old_config.get(key, {}), new_value)
        else:
            old_config[key] = new_value
    return old_config

def load_config(config, config_filename):
    if not config_filename is Path:
        config_filename = scripts_path / config_filename
    with open(config_filename, "r") as config_file:
        return update_config(config, json.load(config_file))

parser = argparse.ArgumentParser(
    description='Query config settings.')
parser.add_argument('-q', '--query', required=True, action='append')
parser.add_argument('configs_json', nargs='+')
args = parser.parse_args()
config = {}
for config_json in args.configs_json:
    config = load_config(config, config_json)

first = True
for query in args.query:
    config_node = config
    found = True
    for field in query.split('.'):
        if not field in config_node:
            found = False
            break
        config_node = config_node[field]
    if first:
        first = False
    else:
        print('|', end='')
    if found:
        print(config_node, end='')
    else:
        print(f'[{query}-unknown]', end='')
if not first:
    print('')
