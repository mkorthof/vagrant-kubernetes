@echo off

:: Kubevg :: Wrapper for Vagrant and kubectl to be able to use multiple Kubernetes versions

:: allow alphanumeric subdir names as <k8s-verion>
SET K8S_ALPHA=0

SET "SCRIPT=%~nx0"
SETLOCAL EnableDelayedExpansion
SET K8S_VERSION=
SET VAGRANT_VAGRANTFILE=
SET /A NAME_ERR=0
SET /A RECREATE=0
SET /A REINSTALL=0

SET "NAME_RE=^[0-9]"
IF NOT %K8S_ALPHA% EQU 1 (
  SET "NAME_RE=^[0-9a-zA-F]"
)

SET "CURDATE=%DATE:~-4%-%DATE:~-7,2%-%DATE:~-10,2% %TIME:~0,2%:%TIME:~3,2%:%TIME:~6,2%"

IF "%1"=="" ( GOTO :help )
IF "%1"=="/?" ( GOTO :help )
( echo %* | find /i "--version" >NUL 2>&1 ) && GOTO :k8s_ver
( echo %* | find /i "--list" >NUL 2>&1 ) && GOTO :k8s_list
( echo %* | find /i "--clip" >NUL 2>&1 ) && GOTO :k8s_clip
( echo %* | find /i "--gitver" >NUL 2>&1 ) && ( CALL :k8s_ver git & GOTO :EOF )
( echo %* | find /i "--proxy" >NUL 2>&1 ) && ( GOTO :k8s_proxy & GOTO :EOF )
( echo %* | find /i "--create" >NUL 2>&1 ) && GOTO :k8s_create
( echo %* | find /i "--install" >NUL 2>&1 ) && GOTO :k8s_create
(( echo %* | find /i "--recreate" >NUL 2>&1 ) || ( echo %* | find /i "--reinstall" >NUL 2>&1 )) && (
  SET /A RECREATE=1 & GOTO :vg_recreate
)
(( echo %* | find /i "vagrant" >NUL 2>&1 ) || ( echo %* | find /i "kubectl" >NUL 2>&1 )) || (
  ( echo %* | find /i "-h" >NUL 2>&1 ) && GOTO :help
)

CALL :k8s_dir
IF %i% GTR 0 (
  CALL :k8s_chk %1
  IF NOT EXIST "%1" (
    echo ERROR: Dir "%1" does not exist
    echo        try: ".\%SCRIPT% -h" for help
    GOTO :EOF
  )
  IF /I "%2"=="vagrant" (
    IF NOT "%3"=="" (
      IF "%3"=="up" (
        GOTO :vg_run
      )
      IF EXIST "%1\.vagrant" (
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
    IF NOT "%3"=="" (
      IF EXIST "%1\admin.conf" (
        GOTO :k8s_kctl
      ) ELSE (
        echo ERROR: Version "%1" does not have an "admin.conf" file
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
  echo For that to work first change "K8S_VERSION" in Vagrantfile.
  echo:
  echo Use "%SCRIPT -h" for help
  echo:
  GOTO :EOF
)

:vg_recreate
  CALL :k8s_dir
  IF %i% GTR 0 (
    CALL :k8s_chk %2
    IF NOT !NAME_ERR! EQU 1 (
      IF EXIST Vagrantfile (
        IF EXIST "%2\.vagrant" (
          taskkill /IM ruby.exe /F >NUL 2>&1
          taskkill /IM vagrant.exe /F >NUL 2>&1
          IF "%1"=="--recreate" (
            echo:
            echo [kubevg] Re-creating "%2" using "vagrant destroy" and "up" ...
            echo:
            CALL :vg_run %2 vagrant destroy -f & cd .. & CALL :vg_run %2 vagrant up
          ) ELSE (
            IF "%1"=="--reinstall" (
              echo:
              echo [kubevg] Reinstall: remove/create "%2" then run "vagrant destroy" and "up" ...
              echo:
              CALL :vg_run %2 vagrant destroy -f & cd ..
              IF EXIST "%2" (
                del /F /S /Q "%2" & rmdir /S /Q "%2"
              )
              mkdir "%2" && CALL :k8s_copy %2
              CALL :vg_run %2 vagrant up
            )
          )
        ) ELSE (
          echo ERROR: .vagrant in subdir "%2" not found
          EXIT /B
        )
      ) ELSE (
        echo ERROR: Vagrantfile not found
        EXIT /B
      )
    )
  )
  GOTO :EOF

:vg_run
  SET K8S_VERSION=%1
  IF "%3"=="up" (
    IF %RECREATE% EQU 0 (
      IF NOT EXIST "%1" (
        mkdir "%1" && CALL :k8s_copy %1
      )
    )
    echo:
    echo [kubevg] Started "up" at %CURDATE%
    echo [kubevg] Currently using version/subdir: "%1"
    echo:
  )
  cd %1 && SET VAGRANT_VAGRANTFILE=..\Vagrantfile && vagrant %3 %4 %5 %6 %7 %8 %9
  IF "%3"=="destroy" (
    IF %RECREATE% EQU 0 (
      IF EXIST "..\%1" (
        SET /A DO_RM=0
        IF /i "%4"=="-f" (
          SET /A DO_RM=1
        ) ELSE (
          echo:
          SET /p p="Remove subdir "%1" ? [y/N] "
          IF /i "%p%"=="y" (
            SET /A DO_RM=1
          )
        )
        IF !DO_RM! EQU 1 (
          echo [kubevg] Deleting "%1"
          cd .. & del /F /S /Q "%1" && rmdir /S /Q "%1"
        )
      )
    )
  )
  GOTO :EOF

:k8s_dir
  SET "DIR_RE=^[0-9]"
  IF %K8S_ALPHA% EQU 1 (
    SET "DIR_RE=^[0-9a-zA-F]"
  )
  SET i=0 & SET a=
  FOR /F "delims=" %%a IN ('DIR /AD /B ^| FINDSTR /R "%DIR_RE%"') DO (
    SET /A i+=1
    IF NOT "%%a"=="tools" (
      SET "a=%%a !a!"
    )
  )
  GOTO :EOF

:k8s_chk
 ( echo %1 | FINDSTR /R "%NAME_RE%" >NUL 2>&1 ) || (
   SET /A NAME_ERR=1
   echo ERROR: Got "%1" but expected version, e.g. "1.15.0" ^(try %SCRIPT% -h^)
   IF %K8S_ALPHA% EQU 1 (
     echo        Or a valid name, e.g. "mykube"
   )
 )
 GOTO :EOF

:k8s_clip
  IF EXIST "%2\dashboard-token.txt" (
    FOR /F "tokens=1,2" %%x IN ('type %2\dashboard-token.txt ^| find "token:"') DO (
      echo %%y | clip.exe && echo [kubevg] Copied Kubernetes Dashboard token to Windows clipboard:
      echo: & echo %%y
    )
  ) ELSE (
    echo [kubevg] Kubernetes version "%2" not found.
  )
  GOTO :EOF

:k8s_list
  CALL :k8s_dir
  IF %i% GTR 0 (
    echo:
    echo [kubevg] Found %i% Kubernetes versions/subdirs:
    echo          %a:~,-1%
    echo:
    echo   Cluster/API info: "kubevg <k8s-version> kubectl cluster-info"
    echo   Token: "kubevg --clip <k8s-version>"
    echo   Dashboard: Open "<k8s-version>\dashboard.html" in web browser
  ) ELSE (
    echo [kubevg] No Kubernetes versions/subdirs found.
  )
  GOTO :EOF

:k8s_copy
  echo [kubevg] Copying example service/ingress yaml files to "%1"...
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
  IF "%1"=="git" (
    IF DEFINED curl (
      IF DEFINED curl (
        IF DEFINED jq (
          %curl% -s %git_url%/tags | jq ".[] .name"
          %curl% -s %git_url%/git/refs/tags | jq ".[] .ref"
          GOTO :EOF
        )
        echo ERROR: Could not find required curl.exe, please install cURL. & GOTO :EOF
      )
      echo ERROR: Could not find required jq.exe , please install jq. & GOTO :EOF
    )
  ) ELSE (
    IF DEFINED curl ( curl -s %ubuntu_url% | FIND "Version:" & GOTO :EOF )
    IF DEFINED powershell (
      %powershell% -c "(Invoke-WebRequest %ubuntu_url%).Content.Split(\"`r`n\") | Select-String -ca 'Version:'"
      GOTO :EOF
    )
    IF DEFINED wget ( %wget% -q -O - %ubuntu_url% | FIND "Version:" & GOTO :EOF )
    echo ERROR: Could not find required curl.exe, wget.exe or PowerShell.
    echo Please install one of these tools.
  )
  GOTO :EOF

:k8s_create
  IF NOT "%2"=="" (
    ( echo "%2" | FIND "\" >NUL 2>&1 ) && (
      echo ERROR: illegal character(s^) in k8s version/name
      GOTO :EOF
    )
    IF NOT EXIST "%2" (
      IF EXIST Vagrantfile (
        mkdir "%2"
        echo:
        echo [kubevg] Created dir "%2", running "vagrant up"...
        CALL :k8s_copy %2
        CALL :vg_run %2 vagrant up
        GOTO :EOF
      ) ELSE (
        echo ERROR: Vagrantfile not found, make sure you're in the correct dir
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
  echo:
  echo [kubevg] Currently using: %1
  echo:
  cd %1 && kubectl --kubeconfig admin.conf %3 %4 %5 %6 %7 %8 %9
  GOTO :EOF

:k8s_proxy
  IF NOT "%2"=="" (
    IF EXIST "%2" (
      echo:
      echo [kubevg] Starting Proxy and Kubernetes Dashboard for "%2"...
      echo:
      CALL :k8s_clip %1 %2
      cd %2
REM      IF EXIST ".proxy" (
REM        FOR /f %%i IN (.proxy) DO SET /A proxy_port=%%i
REM        start "" "http://localhost:!proxy_port!/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
REM        GOTO :EOF
REM      ) ELSE (
REM        echo:
REM        echo Could not open Kubernetes Dashboard on Forwarded VM port (file '.proxy' not found^)
REM        echo Trying local kubectl proxy instead...
REM        echo:
        IF EXIST "admin.conf" (
          start "Kubernetes Proxy" kubectl proxy --kubeconfig admin.conf
          start "" "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
          GOTO :EOF
        ) ELSE (
          echo ERROR: Version "%2" does not have needed "admin.conf" file
          GOTO :EOF
        )
REM      )
    ) ELSE (
      echo ERROR: Dir "%2" does not exist
      echo        try: ".\%SCRIPT% -h" for help
      GOTO :EOF
    )
  ) ELSE (
    echo ERROR: Missing version
    GOTO :EOF
  )
  GOTO :EOF

:help
  echo:
  echo -------------------------------------------------------------------------------
  echo [kubevg]                 (Kube)rnetes (V)a(g)rant wrapper
  echo -------------------------------------------------------------------------------
  echo:
  echo   This wrapper will change dir to "k8s-version" subdir first before running
  echo   running Vagrant or kubectl, thus allowing multiple Kubernetes version
  echo   to co-exist (using the same Vagrantfile).
  echo:
  echo SYNTAX:  ".\%SCRIPT% [--help|--version|--list|--clip|--proxy] <k8s-version>
  echo          ".\%SCRIPT% [--create|--recreate|--reinstall] <k8s-version>"
  echo:
  echo OPTIONS: --help show these help instructions
  echo          --list show available Kubernetes version subdirs
  echo          --version show available Kubernetes Ubuntu package versions
  echo          --create ^<k8s-version^> create new version subdir, runs "vagrant up"
  echo          --recreate ^<k8s-version^> re-create using "vagrant destroy" then "up"
  echo          --reinstall ^<k8s-version^> remove version subdir first, then recreate
  echo          --clip ^<k8s-version^> copy K8s Dashboard token to clipboard
  echo          --proxy ^<k8s-version^> start proxy and K8s Dashboard
  echo:
  echo WRAPPER SYNTAX: ".\%SCRIPT% <k8s-version> [vagrant|kubectl <command>]"
  echo      ^> VAGRANT: ".\%SCRIPT% <k8s-version> vagrant <help|commmand>"
  echo      ^> KUBECTL: ".\%SCRIPT% <k8s-version> kubectl <help|commmand>"
  echo:
  echo EXAMPLES: ".\%SCRIPT% --create 1.13.0"
  echo           ".\%SCRIPT% 1.13.0 vagrant ssh kubevg-host0"
  echo           ".\%SCRIPT% 1.13.0 kubectl get nodes"
  echo:
