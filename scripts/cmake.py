#!/usr/bin/env python

import argparse
import collections.abc
from datetime import datetime
import json
from jsonschema import validate
from pathlib import Path
import platform
import os
import re
import shutil
import subprocess
import sys
from timeit import default_timer as timer
import traceback
from urllib.parse import unquote, urlparse

if sys.prefix == sys.base_prefix:
    raise RuntimeError(
        f'This script is intended to be run from a virtual Python environment.')

def version_to_str(version):
    return '.'.join(map(str, version))

# def str_to_version(name: str):
#     search_result = re.search(r'(\d{4})-(\d{2})-(\d{2})', name)
#     return (int(search_result.group(1)),
#             int(search_result.group(2)),
#             int(search_result.group(3)))

def check_version(version, version_constrtaints):
    for version_constrtaint in version_constrtaints.split(','):
        version_constrtaint = re.search(r'(=|<|<=|>|>=)' + r'\.'.join([r'(\d+)'] * len(version)), version_constrtaint)
        if version_constrtaint is None:
            raise ValueError(f"Malformed version constraint: '{version_constrtaints}'")
        reference_version = tuple(int(version_constrtaint.group(i)) for i in range(2, 2 + len(version)))
        match version_constrtaint.group(1):
            case '=':
                if not version == reference_version:
                    return False
            case '<':
                if not version < reference_version:
                    return False
            case '<=':
                if not version <= reference_version:
                    return False
            case '>':
                if not version > reference_version:
                    return False
            case '>=':
                if not version >= reference_version:
                    return False
    return True


scripts_path = Path(__file__).parent.absolute()
base_path = scripts_path.parent
os.chdir(base_path)
if platform.system() == "Windows":
    # On Windows the outer .cmd script makes use of the "choice" program,
    # which for some reason disables interpretation of VT100 escape sequences.
    # This is a dirty hack to re-enable VT100 support by starting an empty shell
    os.system('')


class Builder:
    def __init__(self):
        self.environment = os.environ.copy()
        architecture = platform.machine()
        if architecture == 'x86_64' or architecture == 'AMD64':
            self.host_architecture = 'x86_64'
            self.host_architecture_short = 'x64'
        else:
            # ToDo: Detect the other possible architectures x86_32, aarch64, and arm* on all supported systems.
            raise NotImplementedError(
                'Unknown host system {}.'.format(architecture))
        self.host_system = platform.system().lower()

        self.env_cc = self.environment['CC'] if 'CC' in self.environment else None
        self.env_cxx = self.environment['CXX'] if 'CXX' in self.environment else None

        parser = argparse.ArgumentParser(
            description='Prepare environment and call cmake.')
        parser.add_argument('configs_json', nargs='+')
        parser.add_argument('--drop-to-shell', action='store_const', const=True, default=False,
                            help='Drop to fully configured command shell after calling CMake.')
        args = parser.parse_args()
        self.drop_to_shell = args.drop_to_shell

        with open(scripts_path / "config.schema.json", "r") as config_schema_file:
            config_schema = json.load(config_schema_file)
        for config_json in sorted(args.configs_json):
            self._load_config(config_json)
        validate(instance=self.config, schema=config_schema)
        print("Using config:")
        print(json.dumps(self.config, indent=4))

        self.target_architecture = self.config['target-architecture']
        if self.target_architecture == 'x86_64':
            self.target_architecture_short = 'x64'
        else:
            self.target_architecture_short = self.target_architecture
        self.target_sub = self.config['target-sub-architecture']
        self.target_system = self.config['target-system']
        self.vendor = self.config['vendor']
        self.msvs_installer = self.config.get('msvs-installer')
        self.cpp_build_system = self.config['cpp-build-system']
        if 'CC' in self.config['environment']:
            self.env_cc = self.config['environment']['CC']
        if 'CXX' in self.config['environment']:
            self.env_cxx = self.config['environment']['CXX']
        self.vcpkg_path = Path(os.path.expanduser(self.config['vcpkg-path'].replace('\\', '/')))
        if not self.vcpkg_path.is_absolute():
            self.vcpkg_path = base_path / self.vcpkg_path
        self.vcpkg_buildtrees_root = Path(os.path.expanduser(
            self.config['vcpkg-buildtrees-root'].replace('\\', '/')))
        self.definitions = self.config['definitions']
        self.cpp_toolset = self.config['cpp-toolset']
        self.cpp_runtime = self.config['cpp-runtime']

        # Eventually autodetect C and C++ compilers according to toolset.
        if self.env_cc is None:
            if self.cpp_toolset.startswith('msvc'):
                self.env_cc = 'cl'
            elif self.cpp_toolset.startswith('gcc'):
                self.env_cc = 'gcc'
            elif self.cpp_toolset.startswith('clang'):
                self.env_cc = 'clang'
            else:
                raise RuntimeError(f'Unknown toolset "{self.cpp_toolset}".')
            self.env_cc = shutil.which(self.env_cc)
        if self.env_cc is not None:
            self.env_cc = Path(self.env_cc)

        if self.env_cxx is None:
            if self.cpp_toolset.startswith('msvc'):
                self.env_cxx = 'cl'
            elif self.cpp_toolset.startswith('gcc'):
                self.env_cxx = 'g++'
            elif self.cpp_toolset.startswith('clang'):
                self.env_cxx = 'clang++'
            else:
                raise RuntimeError(f'Unknown toolset "{self.cpp_toolset}".')
            self.env_cxx = shutil.which(self.env_cxx)
        if self.env_cxx is not None:
            self.env_cxx = Path(self.env_cxx)

        if self.env_cc is None or shutil.which(str(self.env_cc)) is None:
            raise RuntimeError(f'Cannot find C compiler "{self.env_cc}".')
        if self.env_cxx is None or shutil.which(str(self.env_cxx)) is None:
            raise RuntimeError(f'Cannot find C++ compiler "{self.env_cxx}".')
        self.env_cc = self.env_cc.as_posix()
        self.env_cxx = self.env_cxx.as_posix()
        # self.environment['CC'] = str(self.env_cc)
        # self.environment['CXX'] = str(self.env_cxx)

        vcpkg_assets_cache_path = Path(os.path.expanduser(
            self.config['vcpkg-assets-cache-path'].replace('\\', '/')))
        if ',;' in str(vcpkg_assets_cache_path):
            raise RuntimeError(f'The vcpkg assets cache path "{vcpkg_assets_cache_path}" ' +
                               'must neither contain comma (",") nor semicolon (";") characters.')
        if not vcpkg_assets_cache_path.exists():
            print(f'Creating non-existent vcpkg assets cache path "{vcpkg_assets_cache_path}"... ', end='')
            try:
                vcpkg_assets_cache_path.mkdir(parents=True, exist_ok=True)
                print(f'OK')
            except Exception as ex:
                print(f'Error: Cannot create path.')
                exit(1)
        if self.config['vcpkg-assets-cache-readonly']:
            vcpkg_asset_cache_rw = 'read;x-block-origin'
        else:
            vcpkg_asset_cache_rw = 'readwrite'
        self.vcpkg_asset_sources = f'clear;x-azurl,file:///{vcpkg_assets_cache_path},,{vcpkg_asset_cache_rw}'

        vcpkg_binary_cache_path = Path(os.path.expanduser(
            self.config['vcpkg-binary-cache-path']
            .replace('\\', '/')
            .replace('${target-architecture}', self.target_architecture)
            .replace('${target-sub-architecture}', self.target_sub)
            .replace('${target-system}', self.target_system)
            .replace('${vendor}', self.vendor)
            .replace('${cpp-runtime}', self.cpp_runtime)))
        if ',;' in str(vcpkg_binary_cache_path):
            raise RuntimeError(f'The vcpkg binary cache path "{vcpkg_binary_cache_path}" ' +
                               'must neither contain comma (",") nor semicolon (";") characters.')
        if not vcpkg_binary_cache_path.exists():
            print(f'Creating non-existent vcpkg binary cache path "{vcpkg_binary_cache_path}"... ', end='')
            try:
                vcpkg_binary_cache_path.mkdir(parents=True, exist_ok=True)
                print(f'OK')
            except Exception as ex:
                print(f'Error: Cannot create path.')
                exit(1)
        if self.config['vcpkg-binary-cache-readonly']:
            vcpkg_binary_cache_rw = 'read'
        else:
            vcpkg_binary_cache_rw = 'readwrite'
        self.vcpkg_binary_sources = f'clear;files,{vcpkg_binary_cache_path},{vcpkg_binary_cache_rw}'

    def triple(self):
        return f'{self.target_architecture}{self.target_sub}-{self.config["target-system"]}-{self.cpp_runtime}'

    def check_cmake(self):
        print('Checking availability and version of cmake... ', end='')
        self.cmake_path = shutil.which('cmake')
        if not self.cmake_path is None:
            self.cmake_path = Path(self.cmake_path)
            command = [self.cmake_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Error: Cannot query cmake version from executable "{self.cmake_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'cmake version (\d+)\.(\d+)\.(\d+)', stdout_data.decode('ascii'))
            cmake_version = (int(search_result.group(1)), int(
                search_result.group(2)), int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['cmake']
            if not check_version(cmake_version, version_constraints):
                print(f'Error: Expected CMake version {version_constraints}, ' +
                      f'but found version {version_to_str(cmake_version)} in "{self.cmake_path}".')
                exit(1)
        else:
            print(f'Error: Cannot locate CMake executable.')
            exit(1)
        print(f'OK (found version {version_to_str(cmake_version)} in "{self.cmake_path}")')

    def check_ninja(self):
        print('Checking availability and version of ninja... ', end='')
        self.ninja_path = shutil.which('ninja')
        if not self.ninja_path is None:
            self.ninja_path = Path(self.ninja_path)
            command = [self.ninja_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Error: Cannot query ninja version from executable "{self.ninja_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'(\d+)\.(\d+)\.(\d+)', stdout_data.decode('ascii'))
            ninja_version = (int(search_result.group(1)), int(
                search_result.group(2)), int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['ninja']
            if not check_version(ninja_version, version_constraints):
                print(f'Error: Expected ninja version {version_constraints}, ' +
                      f'but found version {version_to_str(ninja_version)} in "{self.ninja_path}".')
                exit(1)
        else:
            print(f'Error: Cannot locate ninja executable.')
            exit(1)
        print(f'OK (found version {version_to_str(ninja_version)} in "{self.ninja_path}")')

    def check_clang_format(self):
        print('Checking availability and version of clang-format... ', end='')
        self.clang_format_path = shutil.which('clang-format')
        if not self.clang_format_path is None:
            self.clang_format_path = Path(self.clang_format_path)
            command = [self.clang_format_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Error: Cannot query clang-format version from executable "{self.clang_format_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'clang-format version (\d+)\.(\d+)\.(\d+)', stdout_data.decode('ascii'))
            clang_format_version = (int(search_result.group(1)), int(
                search_result.group(2)), int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['clang-format']
            if not check_version(clang_format_version, version_constraints):
                print(f'Error: Expected clang-format version {version_constraints}, ' +
                      f'but found version {version_to_str(clang_format_version)} in "{self.clang_format_path}".')
                exit(1)
        else:
            print(f'Error: Cannot locate clang-format executable.')
            exit(1)
        print(f'OK (found version ' +
            f'{version_to_str(clang_format_version)} in "{self.clang_format_path}")')
        
    def check_git(self):
        print('Checking availability and version of git... ', end='')
        self.git_path = shutil.which('git')
        if not self.git_path is None:
            self.git_path = Path(self.git_path)
            command = [self.git_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Error: Cannot query git version from executable "{self.git_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'git version (\d+)\.(\d+)\.(\d+)\.', stdout_data.decode('ascii').partition('\n')[0])
            git_version = (int(search_result.group(1)), int(
                search_result.group(2)), int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['git']
            if not check_version(git_version, version_constraints):
                print(f'Error: Expected git version {version_constraints}, ' +
                      f'but found version {version_to_str(git_version)} in "{self.git_path}".')
                exit(1)
        else:
            print(f'Error: Cannot locate git executable.')
            exit(1)
        print(f'OK (found version ' +
            f'{version_to_str(git_version)} in "{self.git_path}")')
        
    def check_git_lfs(self):
        print('Checking availability and version of git lfs... ', end='')
        self.git_lfs_path = shutil.which('git-lfs')
        if not self.git_lfs_path is None:
            self.git_lfs_path = Path(self.git_lfs_path)
            command = [self.git_lfs_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Error: Cannot query git lfs version from executable "{self.git_lfs_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'git-lfs/(\d+)\.(\d+)\.(\d+)', stdout_data.decode('ascii'))
            git_lfs_version = (int(search_result.group(1)), int(
                search_result.group(2)), int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['git-lfs']
            if not check_version(git_lfs_version, version_constraints):
                print(f'Error: Expected git lfs version {version_constraints}, ' +
                      f'but found version {version_to_str(git_lfs_version)} in "{self.git_lfs_path}".')
                exit(1)
        else:
            print(f'Error: Cannot locate git executable.')
            exit(1)
        print(f'OK (found version ' +
            f'{version_to_str(git_lfs_version)} in "{self.git_lfs_path}")')

    def check_vcpkg(self):
        print('Checking availability and version of vcpkg... ', end='')
        vcpkg_exe = 'vcpkg.exe' if platform.system() == 'Windows' else 'vcpkg'
        self.vcpkg_exe_path = shutil.which(self.vcpkg_path / vcpkg_exe)
        if not self.vcpkg_exe_path is None:
            self.vcpkg_exe_path = Path(self.vcpkg_exe_path)
            command = [self.vcpkg_exe_path, '--version']
            process = subprocess.Popen(command, env=self.environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout_data, stderr_data = process.communicate()
            if process.returncode != 0:
                print(f'Cannot query vcpkg version from executable "{self.vcpkg_path}".')
                exit(process.returncode)
            search_result = re.search(
                r'vcpkg package management program version (\d{4})-(\d{2})-(\d{2})-([0-9a-f]{40})', stdout_data.decode('ascii'))
            vcpkg_version = (int(search_result.group(1)),
                             int(search_result.group(2)),
                             int(search_result.group(3)))
            version_constraints = self.config['expected-versions']['vcpkg']
            if not check_version(vcpkg_version, version_constraints):
                print(f'Error: Expected vcpkg version {version_constraints}, ' +
                      f'but found version {version_to_str(vcpkg_version)} in "{self.vcpkg_path}".')
                exit(1)
            if self.host_system == 'windows' and len(str(self.vcpkg_buildtrees_root)) > 5:
                print('Error: Please configure an exceptionally short path for the config variable "vcpkg-buildtrees-root" ' +
                      '(such as "c:/b/", see `subst` and `mklink` commands), as otherwise some builds will fail.')
                exit(1)

            # Make sure again that the data collection by Microsoft is disabled.
            disable_telemetry_path = self.vcpkg_path / 'vcpkg.disable-metrics'
            if not disable_telemetry_path.exists():
                disable_telemetry_path.touch()
        else:
            print(f'Cannot locate vcpkg executable.')
            exit(1)
        print(f'OK (found version {version_to_str(vcpkg_version)} in "{builder.vcpkg_exe_path}")')

    def filter_environment(self):
        path_delimiter = ';' if platform.system() == 'Windows' else ':'
        paths = [self.cmake_path.parent.as_posix()]
        for path in self.environment.get('PATH', '').split(path_delimiter):
            if '\\PowerShell\\' in path:
                print('Error: Found irregular PowerShell installation in your PATH environment variable. Please remove it from your PATH.')
                exit(1)
            paths += [path]
        self.environment['PATH'] = path_delimiter.join(paths)

    def cmake(self):
        build_path = base_path / \
            f'build-{self.triple()}-{self.cpp_build_system}{self.config["build-path-suffix"]}'
        cmake_path = build_path / 'cmake'
        os.makedirs(cmake_path, exist_ok=True)
        toolchain_path = base_path / 'cmake' / \
            f'Toolchain-{self.triple()}.cmake'
        install_path = base_path / "production"

        # Store a copy of the combined config in our temporary build folder.
        combined_config_filename = build_path / "config.json"
        with open(combined_config_filename, "w") as config_file:
            config_file.write(json.dumps(self.config, indent=4))
        print(f'Effective config written to "{combined_config_filename}".')

        cmake_cache_path = build_path / Path("CMakeCache.txt")
        if cmake_cache_path.exists():
            os.remove(cmake_cache_path)

        # We need to transport the absolute path to the vcpkg cmake toolchain file to our own
        # toolchain files (`cmake/Toolchain*.cmake`), so it can be chain-loaded.
        # Passing the value by cmake command line (via `-DVCPKG_TOOLCHAIN_PATH=<path>`) doesn't work
        # because CMake doesn't make these variables available within toolchain files.
        # Passing the variable via environment variable (self.environment['VCPKG_TOOLCHAIN_PATH'] = <path>)
        # only works for direct script invocation, but breaks when CMake is automatically
        # rerun within Visual Studio. Thus we take the third option by writing the path to
        # a custom file `vcpkg-path.txt` within the build folder.
        with open(build_path / 'vcpkg-path.txt', 'w') as f:
            f.write(str(self.vcpkg_path))

        command = [self.cmake_path, '-S', '.', '-B', build_path]
        if self.cpp_build_system == 'ninja':
            command = command + [
                '-G', 'Ninja Multi-Config',
                '-DCMAKE_MAKE_PROGRAM=ninja',
                f'-DCMAKE_C_COMPILER={self.env_cc}',
                f'-DCMAKE_CXX_COMPILER={self.env_cxx}'
            ]
        elif self.cpp_build_system == 'msbuild':
            command = command + [
                '-G', 'Visual Studio 17 2022',
                '-A', 'x64',
                '-Thost=x64'
            ]
        vcpkg_install_options = [f'--x-buildtrees-root={self.vcpkg_buildtrees_root}']
        if self.config["vcpkg-debug"]:
            vcpkg_install_options = vcpkg_install_options + ['--debug']
        if 'vcpkg-overlay-ports' in self.config:
            vcpkg_install_options = vcpkg_install_options + [f'--overlay-ports={self.config["vcpkg-overlay-ports"]}']
        if 'vcpkg-overlay-triplets' in self.config:
            vcpkg_install_options = vcpkg_install_options + [f'--overlay-triplets={self.config["vcpkg-overlay-triplets"]};']
        command = command + [
            f'-DCMAKE_TOOLCHAIN_FILE={toolchain_path}',
            # This not only removes the CMake default configuration type MinSizeRel from the list,
            # but also relocates Release to the front. This resolves a MSVC specific issue with 3rdparty libraries,
            # that usually only provide Debug and Release, to chose Release as the fallback for RelWithDebInfo.
            # See https://gitlab.kitware.com/cmake/cmake/-/issues/20319 for more details.
            '-DCMAKE_CONFIGURATION_TYPES=Release;RelWithDebInfo;Debug',
            '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON',
            f'-DCMAKE_INSTALL_PREFIX={install_path}',
            f'-DCLANG_FORMAT_PATH:PATH={self.clang_format_path}',
            f'-DBUILD_PATH_SUFFIX:STRING={self.config["build-path-suffix"]}',
            f'-DVCPKG_HOST_TRIPLET:STRING={self.target_architecture_short}-{self.config["target-system"]}-{self.vendor}-{self.config["cpp-runtime"]}',
            f'-DVCPKG_TARGET_TRIPLET:STRING={self.target_architecture_short}-{self.config["target-system"]}-{self.vendor}-{self.config["cpp-runtime"]}',
            f'-DVCPKG_INSTALL_OPTIONS={";".join(vcpkg_install_options)}',
            f'-DX_VCPKG_ASSET_SOURCES:STRING={self.vcpkg_asset_sources}',
            f'-DVCPKG_BINARY_SOURCES:STRING={self.vcpkg_binary_sources}',
            f'-DX_VCPKG_APPLOCAL_DEPS_INSTALL:BOOL=ON',
            # '--debug-find',
        ]
        if self.config['cpp-toolset'].startswith('msvc'):
            command = command + [
                f'-DUSE_CPP_TOOLSET_VERSION={self.config["cpp-toolset-version"]}'
            ]

        for key, value in self.definitions.items():
            command = command + [f'-D{key}={value}']

        command_string = ' '.join(
            f'"{i}"' if ' ' in str(i) else f"{i}" for i in command)

        if self.drop_to_shell:
            print('Enter fully configured and set up sub-shell for investigation.')
            print('Call CMake with the following arguments:')
            print(command_string)
            print('')
            print('Call `exit` to close sub-shell.')
            # Open a separate shell instance instead of calling CMake.
            command = ['cmd.exe', '/K']

        with subprocess.Popen(command,
                              stdout = subprocess.PIPE,
                              stderr = subprocess.STDOUT,
                              universal_newlines = True,
                              env=self.environment) as cmake_app:
            for line in cmake_app.stdout:
                # Filter verbose vcpkg debug output on console. You can find the output in
                # ${build_path}/vcpkg-manifest-install.log
                if not line.startswith('[DEBUG]'):
                    sys.stdout.write(line)
            if self.config["vcpkg-debug"]:
                # Copy vcpkg log file to shared drive to ease bug hunting.
                source_log_filename = build_path / "vcpkg-manifest-install.log"
                if source_log_filename.exists():
                    print(f'Note: You can find vcpkg debug output in\n"{source_log_filename.as_posix()}".')
                    if not self.config["build-log-path"] is None:
                        target_log_folder = Path(os.path.expanduser(self.config["build-log-path"]))
                        if target_log_folder.exists():
                            target_log_folder = target_log_folder / self.environment['USERNAME']
                            os.makedirs(target_log_folder.as_posix(), exist_ok=True)
                            target_log_filename = target_log_folder / datetime.now().strftime('%Y-%m-%dT%H_%M_%S_vcpkg-manifest-install.log')
                            shutil.copy(source_log_filename, target_log_filename)
            if (not cmake_app.returncode is None) and (cmake_app.returncode != 0):
                print(f'The command `{command_string}´ failed with error code {cmake_app.returncode}.')
                exit(cmake_app.returncode)

    def _load_config(self, config_filename):
        if not config_filename is Path:
            config_filename = scripts_path / config_filename
        print(f'Loading config "{config_filename}"')
        with open(config_filename, "r") as config_file:
            self.config = Builder._update_config(self.config, json.load(config_file),
                                                 self.config_guard, config_filename.name)

    @staticmethod
    def _update_config(config, new_config, config_guard, config_filename):
        for key, new_value in new_config.items():
            if isinstance(new_value, collections.abc.Mapping):
                config[key] = Builder._update_config(config.get(key, {}), new_value,
                                                     config_guard.get(key, {}), config_filename)
            else:
                # Keep track of where each setting originates from.
                if key in config_guard and config_guard[key] != "config-base.json":
                    print(f'Warning: Config "{key}"="{config[key]}" previously set in "{config_guard[key]}" ' +
                          f'will be overwritten with "{key}"="{new_value}" set in "{config_filename}"!')
                config_guard[key] = config_filename
                config[key] = new_value
        return config

    drop_to_shell = False
    config = {}
    config_guard = {}
    cpp_build_system = None
    cpp_toolset = None
    environment = None
    host_architecture = ''  # x86_64, i386, arm, thumb, mips, etc.
    host_architecture_short = ''  # x64, x32, arm, ...
    host_sub = ''  # for ex. on ARM: v5, v6m, v7a, v7m, etc.
    host_system = ''  # linux, windows, darwin
    # host_abi = ''  # win32, mingw, cygwin, eabi, gnu, android, macho, elf, etc.
    target_architecture = ''
    target_architecture_short = ''
    target_sub = ''
    target_system = ''
    vendor = ''
    cpp_runtime = None  # vc143, libstdc++, libc++, etc.
    env_cc = ''  # gcc, clang, cl, etc.
    env_cxx = ''  # g++, clang++, cl, etc.
    cmake_path = None
    ninja_path = None
    clang_format_path = None
    git_path = None
    git_lfs_path = None
    vcpkg_path = None
    vcpkg_exe_path = None
    vcpkg_asset_sources = None
    vcpkg_binary_sources = None
    # Path to a custom vcpkg buildtree folder, which quickly grows to several hundred GiB in size.
    # The contents of this folder are not strictly required, but allow debugging into third-party libraries.
    vcpkg_buildtrees_root = None
    definitions = []


start = timer()
try:
    print(f'\033]2;Checking prerequisites ...\007')
    # The check for Python is hard-coded.
    print('Checking version of python... ', end='')
    python_version = (sys.version_info.major, sys.version_info.minor)
    if not check_version(python_version, "=3.11"):
        print(f'Error: Expected python version 3.11, but found version {version_to_str(python_version)}.')
        exit(1)
    print(f'OK (found version {version_to_str(python_version)})')

    builder = Builder()

    builder.check_cmake()
    builder.check_ninja()
    builder.check_clang_format()
    # builder.check_git()
    # builder.check_git_lfs()
    builder.check_vcpkg()
    builder.filter_environment()

    # ToDo: Handle config['vcpkg-reuse-suffix'] and setup directory symlink/junction to reuse vcpkg installation folder.

    print(f'\033]2;running cmake ...\007')
    builder.cmake()
    print(f'\033]2;done\007')
except Exception as ex:
    print('Error')
    traceback.print_exc()
    exit(1)
finally:
    end = timer()
    print(f'Script finished in {end - start:.1f} seconds')
