# Fortitude

[Fortitude is a Fortran linter](https://github.com/PlasmaFAIR/fortitude) that can be installed from PYPI via

    # With uv:
    uv tool install fortitude-lint@latest

    # With pip:
    pip install fortitude-lint

After installing, check the version

    fortitude --version

Fortitude is used by navigating to the piclas repository and running

    cd ~/piclas
    fortitude check --output-format=grouped src

which lists any errors that are encountered with their corresponding violation ID.

## Gitlab CI
The Fortitude Gitlab CI/CD stage `fortitude:` is defined in `.gitlab-ci.yml` and the Fortitude settings are stored in `fpm.toml`.

## Pre-commit hook
TODO: The pre-commit hook for Fortitude is configured in ...

## Fixing Fortitude violations (of failing pipelines)
When a pipeline fails in the `fortitude` stage, an error is displayed showing the ID of the violation

    src/timedisc/timedisc_TimeStepECIM.f90:
    606:42 C141 'exit' statement in named 'do' loop missing label 'SUBROUTINE ExactPushSingleParticle(iPart, dt)

which in this case is "C141" and details on this violation can be found by running

    fortitude explain C141

which returns

    C141: missing-exit-or-cycle-label

    Fix is sometimes available.

    What does it do?
    When using exit or cycle in a named do loop, the exit/cycle statement
    should use the loop name

    Example
    name: do
      exit name
    end do name

    Using named loops is particularly useful for nested or complicated loops, as it
    helps the reader keep track of the flow of logic. It's also the only way to exit
    or cycle outer loops from within inner ones.

Fortitude can automatically fix many linter warnings and errors. Simply navigate to the piclas repository and use the `--fix` flag
for Fortitude

    cd ~/piclas
    fortitude check --output-format=grouped src --fix

or

    cd ~/piclas
    fortitude check --output-format=grouped src/particles/pic/models/pic_models.f90 --select C141 --fix

to only fix specific violation IDs in specific .f90 files.

Note that there are two flags for auto-fixing `--fix` and `--unsafe-fixes`
| Flag                       | Description                                                                                |
| :------------------------- | :----------------------------------------------------------------------------------------- |
| `check`                    | Only checks for issues without applying any fixes.                                         |
| `--fix`                    | Applies **safe** automatic fixes (e.g., style-based rules).                                |
| `--unsafe-fixes`           | Applies **both safe and unsafe** automatic fixes (use with caution).                       |
| `--diff`                   | Shows the changes that would be made by `--fix` or `--unsafe-fixes` without applying them. |
| `--help`                   | Displays help information about Fortitude commands and flags.                              |
| `--version`                | Shows the installed version of Fortitude.                                                  |
| `--output-format=<format>` | Specifies the output format (e.g., `grouped`, `json`, `sarif`).                            |

Unsafe fixes may change program behavior or introduce new issues, so use with caution.
If the solution to solving this issue is not straightforward, there are two possibilities that might help by looking into ways how
other developers have fixed it by searching for the violation ID in the git history or source code.

### Search for the violation ID in the git history
Navigate to the piclas directory and search the complete git history (commit messages and changes to the code) for the specific
violation ID via

    cd ~/piclas
    git log --all --grep="C141" -p

which gives

    commit e23cd1267e980174926c309a8848bbc80efd7924 refs/heads/master.dev
    Author: Stephen Copplestone
    Date:   Fri May 29 20:55:38 2026 +0200
        - Fixed Fortitude violation C141: When using exit or cycle in a named do loop, the exit/cycle statement should use the loop name.
        - Replaced abort() statements with CollectiveStop()

and when looking for the specific fix in the commits, there are two ways to fix the violation, where

```diff
   locSideLoop: DO iLocSide = 1,nLocSides
     newSideID = ElemInfo_Shared(ELEM_FIRSTSIDEIND,newElemID) + iLocSide
     ! Cycle over non-BC sides
-    IF (SideInfo_Shared(SIDE_BCID,newSideID).LE.0) CYCLE
+    IF (SideInfo_Shared(SIDE_BCID,newSideID).LE.0) CYCLE locSideLoop
     BCType = PartBound%TargetBoundCond(PartBound%MapToPartBC(SideInfo_Shared(SIDE_BCID,newSideID)))
     ! Cycle over non-rotBC sides
-    IF(BCType.NE.PartBound%RotPeriodicBC) CYCLE
+    IF(BCType.NE.PartBound%RotPeriodicBC) CYCLE locSideLoop

     locSideID = SideInfo_Shared(SIDE_LOCALID,newSideID)
     ! Side is not one of the 6 local sides
-    IF (locSideID.LE.0) CYCLE
+    IF (locSideID.LE.0) CYCLE locSideLoop
     ! Calculate the determinant
     DO NodeNum = 1,4
       !--- A = vector from particle to node coords
```

which solves the issue by adding the name of the loop to the `CYCLE` statement or

```diff
   IF(PDM%ParticleInside(iPart)) THEN
     ASSOCIATE ( oldSpec => PartSpecies(iPart) ,&
           newSpec => SpecDSMC(PartSpecies(iPart))%NextIonizationSpecies )
+      ! allow(C141) because of false-positive Fortitude check
       IF(newSpec.EQ.0) CYCLE
       ASSOCIATE (&
             E_au     => 5.1e11 ,& ! [V/m] atomic unit field strength
```

which ignores the violation check completely by adding the flag `allow(C141)` to the line before the one with the trigger.
Note that there are multiple occasions where a false-positive violation is reported, because Fortitude still has many shortcomings
regarding macros or pre-processor statements.

### Search for the violation ID in the source code itself
Navigate to the piclas source directory and search all Fortran files for the specific ID

    cd ~/piclas/src
    grep -rin --include=*.f90 C141

which returns

    particles/pic/models/pic_models.f90:202:      ! allow(C141) because of false-positive Fortitude check

and shows that, as mentioned in the previous section, the error can simply be ignored in special cases with the flag
`allow(C141)`added to the line before the one with the trigger.


### Create separate commit
When specifically fixing Fortitude violations, make a separate commit noting the violation IDs (e.g. C141) in the commit message
so that other developers can find it when they are tackling the same issue.
When violations are simply ignored, their ID is added to the source code automatically with the flag `allow(C141)`.
