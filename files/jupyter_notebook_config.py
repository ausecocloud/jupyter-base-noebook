# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

import errno
import os
import stat
import subprocess

from jupyter_core.paths import jupyter_data_dir


c = get_config()
c.NotebookApp.ip = '*'
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False

c.NotebookApp.kernel_spec_manager_class = 'environment_kernels.EnvironmentKernelSpecManager'

c.FileContentsManager.delete_to_trash = False


c.GitHubConfig.client_id = os.environ.get('GITHUB_CLIENT_ID', '')
c.GitHubConfig.client_secret = os.environ.get('GIHUB_CLIENT_SECRET', '')
c.GitHubConfig.access_token = os.environ.get('GITHUB_ACCESS_TOKEN', '')

# avoid showing jupyter default kernels
c.KernelSpecManager.ensure_native_kernel = False
if 'DEFAULT_KERNEL_NAME' in os.environ:
    c.MappingKernelManager.default_kernel_name = os.environ['DEFAULT_KERNEL_NAME']


# Generate a self-signed certificate
if 'GEN_CERT' in os.environ:
    dir_name = jupyter_data_dir()
    pem_file = os.path.join(dir_name, 'notebook.pem')
    try:
        os.makedirs(dir_name)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(dir_name):
            pass
        else:
            raise
    # Generate a certificate if one doesn't exist on disk
    subprocess.check_call(['openssl', 'req', '-new',
                           '-newkey', 'rsa:2048',
                           '-days', '365',
                           '-nodes', '-x509',
                           '-subj', '/C=XX/ST=XX/L=XX/O=generated/CN=generated',
                           '-keyout', pem_file,
                           '-out', pem_file])
    # Restrict access to the file
    os.chmod(pem_file, stat.S_IRUSR | stat.S_IWUSR)
    c.NotebookApp.certfile = pem_file
