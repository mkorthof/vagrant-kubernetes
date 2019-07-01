@echo off

:: Kubevg :: Wrapper for Vagrant to be able to use multiple Kubernetes versions

SET "SCRIPT=%~nx0"
SETLOCAL EnableDelayedExpansion
SET K8S_VERSION=
SET VAGRANT_VAGRANTFILE=

IF "%1"=="" ( GOTO :help )
( echo %* | find /i "--version" >nul 2>&1 ) && GOTO :k8s_ver
( echo %* | find /i "version" >nul 2>&1 ) && GOTO :k8s_ver
( echo %* | find /i "--create" >nul 2>&1 ) && GOTO :k8s_create

(( echo %* | find /i "vagrant" >nul 2>&1 ) || ( echo %* | find /i "kubectl" >nul 2>&1 )) || (
  ( echo %* | find /i "--help" >nul 2>&1 ) && GOTO :help
  ( echo %* | find /i "-h" >nul 2>&1 ) && GOTO :help
)

SET i=0 & SET a=
FOR /F "delims=" %%a IN ('DIR /AD /B ^| FINDSTR /V "^\. tools"') DO (
  SET /A i+=1
  SET "a=%%a !a!"
  SET "b=%%a"
)

IF %i% GTR 0 (
  echo [kubevg] Found %i% Kubernetes versions/dirs:
  echo          %a:~,-1%
  IF /I "%2"=="vagrant" (

    IF NOT "%3"=="" (
      IF "%3"=="up" (
        IF NOT EXIST %1 (
          mkdir "%1" && CALL :k8s_copy %1
        )
        GOTO :vg_run
      )
      IF EXIST %1\.vagrant (
        GOTO :vg_run
      ) ELSE (
        echo ERROR: Version "%1" does not have a ".vagrant" dir
        echo        try: ".\%SCRIPT% <k8s-version> vagrant <command>"
        echo        or use '-h' for help
        GOTO :EOF
      )
    ) ELSE (
      echo ERROR: Missing Vagrant command ^(try %SCRIPT% -h^)
      GOTO :EOF
    )
  )
  IF /I "%2"=="kubectl" (
    IF NOT EXIST %1 (
      echo "%1" does not exist
      GOTO :EOF
    )
    IF NOT "%3"=="" (
      IF EXIST %1\admin.conf (
        GOTO :k8s_kctl
      ) ELSE (
        echo ERROR: Version "%1" does not have a "admin.conf" file
        GOTO :EOF
      )
    ) ELSE (
      echo ERROR: Missing kubectl command ^(try %SCRIPT% -h^)
      GOTO :EOF
    )
  )
  echo ERROR: Got "%2" but expected "vagrant" or "kubectl" ^(try %SCRIPT% -h^)
  GOTO :EOF
) ELSE (
  echo:
  echo Kubevg: did not find any Kubernetes versions/dirs
  echo Either run ".\%SCRIPT% --create <k8s-version>" or manually :
  echo "mkdir <ver>" then "SET K8S_VERSION=<ver>"
  
  echo:
  echo You can also skip multi version support and run "vagrant" as usual.
  echo In this case "K8S_VERSION" can be changed in Vagrantfile.
  echo:
  echo Use "%SCRIPT -h" for help
  echo:
  GOTO :EOF
)

:vg_run
  SET K8S_VERSION=%1
  echo [kubevg] Currently using: %1
  echo:
  cd %1 && SET VAGRANT_VAGRANTFILE=..\Vagrantfile && vagrant %3 %4 %5 %6 %7 %8 %9
  GOTO :EOF

:k8s_copy
  copy /Y k8s-minimal-ingress-resource.yaml "%1" 1>NUL
  copy /Y k8s-single-service-ingress.yaml "%1" 1>NUL
  GOTO :EOF

:k8s_ver
  SET "ubuntu_url=https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages"
  SET "git_url=https://api.github.com/repos/kubernetes/kubernetes"
  SET ps_path=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
  SET "curl=" & SET "wget=" & SET "powershell=" & SET "jq="
  SET "bins=curl wget jq"
  SET search="%SystemRoot%\System32" "C:\ProgramData\chocolatey\bin" ^
              "C:\tools\msys64\mingw64\bin" "C:\tools\msys32\mingw32\bin" ^
              "C:\msys64\mingw64\bin" "C:\msys32\mingw32\bin" ^
              "C:\tools\msys32\usr\bin" "C:\tools\msys64\usr\bin" ^
              "C:\msys32\usr\bin" "C:\msys64\usr\bin" ^
              "C:\cygwin\bin" "C:\cygwin64\bin" "C:\cygwin32\bin" ^
              "C:\HashiCorp\Vagrant\embedded\bin" "c:\HashiCorp\Vagrant\embedded\mingw64\bin"
  FOR %%a IN ( %search% ) DO (
    FOR %%b IN ( !%bins! ) DO (
      IF EXIST "%%~a\%%~b.exe" ( SET "%%b=%%~a\%%~b.exe" & SET bins=!bins:%%b=! )
    )
  )
  IF EXIST "%ps_path%" ( SET "powershell=%ps_path%" )
  IF DEFINED curl ( curl -s %ubuntu_url% | FIND "Version:" & GOTO :EOF )
  IF DEFINED powershell (
    %powershell% -c "(Invoke-WebRequest %ubuntu_url%).Content.Split(\"`r`n\") | Select-String -ca 'Version:'"
    GOTO :EOF
  )
  IF DEFINED wget ( %wget% -q -O - %ubuntu_url% | FIND "Version:" & GOTO :EOF )
    REM IF DEFINED jq (
    REM  %curl% -s %git_url%/tags | jq ".[] .name"
    REM  %curl% -s %git_url%/refs/tags | jq ".[] .ref"
    REM )
  echo ERROR: Could not find required curl.exe ^(or alternative^), please install cURL. & GOTO :EOF

:k8s_create
  IF NOT "%2"=="" (
    IF NOT EXIST "%2" (
      IF EXIST Vagrantfile (
        mkdir "%2"
        echo Created dir "%2", running "vagrant up"...
        CALL :k8s_copy %2
        CALL :vg_run %2 vagrant up
        GOTO :EOF
      ) ELSE (
        echo ERROR: Vangrantfile not found, make sure you're in the correct dir
        GOTO :EOF
      )
    ) ELSE (
      echo ERROR: "%2" already exists
      GOTO :EOF
    )
  ) ELSE (
    echo ERROR: Missing version
    GOTO :EOF
  )


:k8s_kctl
  echo [kubevg] Currently using: %1
  echo:
  cd %1 && kubectl --kubeconfig admin.conf %3 %4 %5 %6 %7 %8 %9
  GOTO :EOF

:help
  echo:
  echo [kubevg]
  echo:
  echo This wrapper will chdir to "k8s-version" subdir first before
  echo running Vagrant, allowing multiple Kubernetes versions to co-exist.
  echo:
  echo SYNTAX:  ".\%SCRIPT% [--help|--version] | [--create] <k8s-version> [vagrant|kubectl <command>]"
  echo:
  echo:         [--create] ^<k8s-version^>] create new version subdir and run "vagrant up"
  echo          [--help] show these help instructions
  echo          [--version] list available Kubernetes Ubuntu package versions
  echo:
  echo VAGRANT: ".\%SCRIPT% <k8s-version> vagrant <commmand>"
  echo KUBECTL: ".\%SCRIPT% <k8s-version> kubectl <commmand>"
  echo:
  echo EXAMPLE: ".\%SCRIPT% --create 1.13.0"
  echo          ".\%SCRIPT% 1.13.0 vagrant ssh host0"
  echo          ".\%SCRIPT% 1.13.0 kubectl proxy"
  echo:
  REM echo          [-g] list Kubernetes Git versions
