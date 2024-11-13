#
# Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

import subprocess
import click

UPSTREAM_REMOTE_URL = 'git@github.com:Mellanox/sharp.git'


def run_command(repo_path, command):
    process = subprocess.Popen(
        command.split(),
        cwd=repo_path,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        print(f'Error: {stderr.decode("utf-8")}')
        raise Exception(
            rf'command: {command} failed with error: {process.returncode}')
    return stdout.decode('utf-8')


@click.command()
@click.option('-p', 'repo_path', type=click.Path(exists=True))
@click.option('-rm', '--stash_rebase_master', is_flag=True, required=False, help=rf'Rebase master branch from upstream ({UPSTREAM_REMOTE_URL}), stash and restore local changes')
@click.option('-pm', '--stash_pull_master', is_flag=True, required=False, help=rf'Pull master branch from upstream ({UPSTREAM_REMOTE_URL}), stash and restore local changes')
@click.option('-au', '--add_upstream', is_flag=True, required=False, help='Add upstream remote')
@click.option('-cpr', '--checkout_pr_number', type=int, required=False, help='Checkout origin PR by providing the PR number, example: -cpr 3177')
def main(repo_path, stash_rebase_master, stash_pull_master, add_upstream, checkout_pr_number):
    if not stash_rebase_master and not stash_pull_master and not add_upstream and not checkout_pr_number:
        raise Exception(
            'Invalid parameters, either stash_pull_master (-pm) or add_upstream (-au) must be specified')
    if stash_rebase_master or stash_pull_master:
        if stash_rebase_master:
            original_branch_name = run_command(
                repo_path, 'git rev-parse --abbrev-ref HEAD').strip()
        has_unstaged_changes = run_command(repo_path, 'git diff')
        has_staged_changes = run_command(repo_path, 'git diff --cached')
        has_changes = has_unstaged_changes or has_staged_changes
        if has_changes:
            print(rf'Local changes detected, stashing...')
            run_command(repo_path, 'git stash push -u')
        print('Checkout origin master branch')
        run_command(repo_path, 'git checkout master')
        print('Fetch master from upstream')
        run_command(repo_path, 'git fetch upstream')
        print('Rebase origin master from upstream/master')
        run_command(repo_path, 'git rebase upstream/master')
        print('Update origin master')
        run_command(repo_path, 'git push origin master --force')
        if stash_rebase_master:
            print(rf'Checkout original branch: {original_branch_name}')
            run_command(repo_path, rf'git checkout {original_branch_name}')
            print(rf'Rebase master')
            run_command(repo_path, 'git rebase master')
        if has_changes:
            print(rf'Restore local changes')
            stash_apply_command = 'git stash apply'
            try:
                run_command(repo_path, stash_apply_command)
            except Exception as er:
                print(
                    rf'The command "{stash_apply_command}" failed, you may have conflicts, run "git status" to view files with potential conflicts')
                print(
                    rf'Your local changes were stashed, You can either solve the conflicts or run "{stash_apply_command}" to try and apply your changes again')
                raise
            # stash apply succeeded, remove it
            run_command(repo_path, 'git stash drop stash@{0}')
    if add_upstream:
        existing_remotes = run_command(repo_path, 'git remote -v')
        if 'upstream' in existing_remotes:
            raise Exception('upstream remote already exists in repository')
        print(rf'Add upstream branch with remote: {UPSTREAM_REMOTE_URL}')
        run_command(
            repo_path, rf'git remote add upstream {UPSTREAM_REMOTE_URL}')
    if checkout_pr_number:
        print(rf'Fetch PR {checkout_pr_number}')
        run_command(
            repo_path, rf'git fetch upstream pull/{checkout_pr_number}/head:pr/{checkout_pr_number}')
        run_command(repo_path, rf'git checkout pr/{checkout_pr_number}')
    print('Done')
    return 0


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(str(e))
        raise
