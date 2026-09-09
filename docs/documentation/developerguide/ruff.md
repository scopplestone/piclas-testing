# Ruff
[Ruff is a Python linter and code formatter](https://docs.astral.sh/ruff/) that can be installed from PYPI via

    # With uv:
    uv tool install ruff

    # With pip:
    pip install ruff

After installing, check the version

    ruff --version

Ruff is used by navigating to the piclas repository and running

    cd ~/piclas
    ADDIGNORE=,F821,PLW0602,UP031,DTZ011,TRY002,BLE001,E722,SIM115,RUF012,SIM102,B018,EXE001,S110,LOG015,TRY300,PLC0206,PLR1704,F509,PLE1300,PLW0127,S102,SIM113,RET504,F841,C408,FLY002
    ruff check --extend-ignore=E201,E202,E203,E221,E222,E225,E231,E271,E272"$ADDIGNORE" --line-length=132 --preview docs tools --statistics

which lists any errors that are encountered with their corresponding violation ID, for example

    E722 Do not use bare `except`
      --> tools/visuBox_PartState/visuBox_PartState.py:59:1
       |
    57 |     time = float(timestr)
    58 |     newFile = re.sub(timestr+'.h5', '', args.statefile)+timestr+'_visuBox.h5'
    59 | except :
       | ^^^^^^
    60 |     print("something wrong with "+args.statefile)
    61 |     sys.exit(0)
       |

Running two command with `--statistics` will list a summary with the number of hits for each violiation and with a short description

    ruff check --extend-ignore=E201,E202,E203,E221,E222,E225,E231,E271,E272"$ADDIGNORE" --line-length=132 --preview docs tools --statistics

which gives, for example, the following

    207     F821    undefined-name
     62     UP031   printf-string-formatting
     50     PLW0602 global-variable-not-assigned
     24     TRY002  raise-vanilla-class
     21     DTZ011  call-date-today
     19     E722    bare-except
     19     SIM115  open-file-with-context-handler
     17     BLE001  blind-except
      8     SIM102  collapsible-if
      7     RUF012  mutable-class-default
      6     F841    unused-variable
      5     B018    useless-expression
      5     EXE001  shebang-not-executable
      5     S110    try-except-pass

## Gitlab CI
The Ruff Gitlab CI/CD stage `ruff:` is defined in `.gitlab-ci.yml`.

## Pre-commit hook
TODO: The pre-commit hook for Ruff is configured in ...

## Fixing Ruff violations (of failing pipelines)
When a pipeline failes in the `ruff` stage, an error is displayed showing the ID of the violation

    FLY002 Consider f-string instead of string join
      --> tools/paraview/pdf/43/python_filter_generator.py:81:12
       |
    79 |       </StringVectorProperty>''' % requestUpdateExtent
    80 |
    81 |     return '\n'.join([requestData, requestInformation, requestUpdateExtent])
       |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
       |
    help: Replace with f-string

    Found 1 error.

which in this case is "FLY002" and details on this violation can be found by running

    ruff rule FLY002

which returns

    # static-join-to-f-string (FLY002)

    Derived from the **flynt** linter.

    Fix is always available.

    ## What it does
    Checks for `str.join` calls that can be replaced with f-strings.

    ## Why is this bad?
    f-strings are more readable and generally preferred over `str.join` calls.

    ## Example
    ```python
    " ".join((foo, bar))
    ```

    Use instead:
    ```python
    f"{foo} {bar}"
    ```

    ## Fix safety
    The fix is always marked unsafe because the evaluation of the f-string
    expressions will default to calling the `__format__` method of each
    object, whereas `str.join` expects each object to be an instance of
    `str` and uses the corresponding string. Therefore it is possible for
    the values of the resulting strings to differ, or for one expression
    to raise an exception while the other does not.

    ## References
    - [Python documentation: f-strings](https://docs.python.org/3/reference/lexical_analysis.html#f-strings)

Ruff can automatically fix many violationsby adding the `--fix` flag

    cd ~/piclas
    ruff check --extend-ignore=E201,E202,E203,E221,E222,E225,E231,E271,E272"$ADDIGNORE" --line-length=132 --preview docs tools --fix

which might return with

    No fixes available (1 hidden fix can be enabled with the `--unsafe-fixes` option).

and in this case an unsafe fix might work via `--unsafe-fixes`

    cd ~/piclas
    ruff check --extend-ignore=E201,E202,E203,E221,E222,E225,E231,E271,E272"$ADDIGNORE" --line-length=132 --preview docs tools --unsafe-fixes

which shows a diff of how the violation would be fixed

```diff
78 |         extent that your filter ask up stream for.</Documentation>
79 |       </StringVectorProperty>''' % requestUpdateExtent
80 | 
   -     return '\n'.join([requestData, requestInformation, requestUpdateExtent])
81 +     return f'{requestData}\n{requestInformation}\n{requestUpdateExtent}'
82 | 
83 | 
84 | 
note: This is an unsafe fix and may change runtime behavior

Found 1 error.
[*] 1 fixable with the `--fix` option
```

and can be applied by running the command with both flags `--fix --unsafe-fixes`

    ruff check --extend-ignore=E201,E202,E203,E221,E222,E225,E231,E271,E272"$ADDIGNORE" --line-length=132 --preview docs tools --fix --unsafe-fixes

It is important to make sure that the code still behaves as itended when using an unsafe fix.
| Flag | Description |
|------|-------------|
| `--fix` | Automatically fix lint errors where possible. |
| `--watch` | Watch for file changes and re-run Ruff automatically. |
| `--select=<CODE>` | Select specific lint rules to apply (e.g., `E`, `F`, `I`, `UP`). |
| `--ignore=<CODE>` | Ignore specific lint rules. |
| `--line-length=<N>` | Set the maximum line length (default: `88`). |
| `--statistics` | Show statistics about the linting process. |
| `--diff` | Show a diff of changes Ruff would make (useful for CI/CD). |


If the solution to solving this issue is not straightforward, there are two possibilities that might help by looing into ways how
other developers have fixed it by searching for the violation ID.

###  Search for the violation ID in the git history
Navigate to the piclas directory and search the complete git history (commit messages and changes to the code) for the specific
violation ID via

    cd ~/piclas
    git log --all --grep="FLY002" -p

which gives

    commit 101eb2848fb454739761c572f6a4e41ee51babb4 (HEAD -> update.dev.docu)
    Author: Stephen Copplestone
    Date:   Wed Sep 9 18:50:31 2026 +0200

        Fixed ruff violation FLY002: f-strings are more readable and generally preferred over `str.join` calls.

and when looking for the specific fix in the commits, there are two ways to fix the violation, where

```diff
@@ -78,7 +78,7 @@ def getScriptPropertiesXml(info):
         extent that your filter ask up stream for.</Documentation>
       </StringVectorProperty>''' % requestUpdateExtent
 
-    return '\n'.join([requestData, requestInformation, requestUpdateExtent])
+    return f'{requestData}\n{requestInformation}\n{requestUpdateExtent}'
```

which solves the issue by replacing the `str.join` call with an f-string.
Alternatively, violations can simply be ignored by adding the flag and identifier of the rule `noqa: FLY002` and the exnd of the line as a comment.
This is done in the file `extract_userblock.py` for example

    except :  # noqa: S112  [▼ 1/2]     ■ Do not use bare `except`                                                                                                                        =
        continue

### Search for the violation ID in the source code itself
Navigate to the piclas source directory and search all Python files for the specific ID

    cd ~/piclas/src
    grep -rin --include=*.py S112

which returns

    tools/userblock/extract_userblock.py:87:        except :  # noqa: S112
    tools/userblock/extract_userblock.py:106:        except :  # noqa: S112

and shows that, as mentioned in the previous section, the error can simply be ignored in special cases with the flag
`# noqa: S112` added to the end of the line triggering the error.


### Create separate commit
When specifically fixing Ruff violations, make a separate commit noting the violation IDs (e.g. S112) in the commit message
so that other developers can find it when they are tackling the same issue.
When violations are simply ignored, their ID is added to the source code automatically with the flag+ID combination, e.g., `# noqa: S112`.
