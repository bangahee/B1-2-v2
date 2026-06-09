# B1-2: 리눅스 프로세스 및 시스템 리소스 트러블슈팅

## 1. 프로젝트 개요

본 프로젝트는 제공된 `agent-app-leak` 실행 파일을 Ubuntu 24.04 Docker 환경에서 실행하며 다음 세 가지 시스템 장애 상황을 재현하고 분석한 결과를 정리한 것이다.

1. OOM Crash / Memory Leak
2. CPU Spike / CPU 과점유
3. Deadlock / 교착상태

각 장애는 `monitor.sh`, 애플리케이션 실행 로그, `ps`, `top`, `ps -L`, `strace` 등의 Linux 시스템 도구를 활용하여 관찰하였다. 최종 산출물은 GitHub Issue 형식의 기술 리포트와 증거 로그로 구성된다.

본 프로젝트의 핵심 목표는 단순히 프로세스가 종료되거나 멈춘 결과만 확인하는 것이 아니라, 로그와 관제 데이터를 근거로 장애 원인을 추론하고 Before & After 비교를 통해 조치 결과를 검증하는 것이다.

---

## 2. 실행 환경

* Docker image: `ubuntu:24.04`
* Container name: `B1-2`
* 실행 계정: `mission-user`
* 작업 디렉터리: `/app`
* 실행 파일: `agent-app-leak`
* 포트: `15034`
* 로그 디렉터리: `/app/logs`
* 업로드 디렉터리: `/app/upload_files`
* API key 디렉터리: `/app/api_keys`

제공된 앱은 root가 아닌 일반 사용자 계정에서 실행해야 하므로, Docker 컨테이너 내부에서 `mission-user` 계정을 생성한 뒤 해당 계정으로 테스트를 수행하였다.

---

## 3. 필수 환경변수

애플리케이션 실행을 위해 다음 공통 환경변수를 설정하였다.

```bash
AGENT_HOME=/app
AGENT_LOG_DIR=/app/logs
AGENT_PORT=15034
AGENT_UPLOAD_DIR=/app/upload_files
AGENT_KEY_PATH=/app/api_keys
```

또한 앱 실행에 필요한 디렉터리와 key 파일을 다음과 같이 준비하였다.

```text
/app/api_keys/secret.key
/app/upload_files
/app/logs
```

`secret.key`의 내용은 다음과 같다.

```text
agent_api_key_test
```

장애 유형별로는 다음 환경변수를 변경하여 Before & After를 비교하였다.

* `MEMORY_LIMIT`
* `CPU_MAX_OCCUPY`
* `MULTI_THREAD_ENABLE`

---

## 4. 테스트별 환경변수 및 결과 요약

| 장애 유형                 | Before 설정                  | After 설정                    | 확인 결과                                                                  |
| :-------------------- | :------------------------- | :-------------------------- | :--------------------------------------------------------------------- |
| **OOM / Memory Leak** | `MEMORY_LIMIT=100`         | `MEMORY_LIMIT=300`          | Before에서는 MemoryGuard에 의해 종료, After에서는 Memory Cache Flushed 발생         |
| **CPU Spike**         | `CPU_MAX_OCCUPY=80`        | `CPU_MAX_OCCUPY=50`         | Before에서는 CPU Threshold Violated 및 SIGTERM 종료 확인, After에서는 cooldown 동작 |
| **Deadlock**          | `MULTI_THREAD_ENABLE=true` | `MULTI_THREAD_ENABLE=false` | Before에서는 WAITING/BLOCKED 발생, After에서는 task 정상 완료                      |

---

## 5. 주요 파일 구조

```text
.
├── README.md
├── .gitignore
├── monitor.sh
├── run_helpers.sh
├── reports/
│   ├── oom.md
│   ├── cpu-spike.md
│   └── deadlock.md
└── evidence/
    ├── monitor.sh
    ├── run_helpers.sh
    └── logs/
        ├── oom_before_app.log
        ├── oom_after_app.log
        ├── oom_before_monitor.log
        ├── oom_after_monitor.log
        ├── cpu_before_app.log
        ├── cpu_after_app.log
        ├── cpu_before_monitor.log
        ├── cpu_after_monitor.log
        ├── cpu_before_ps.log
        ├── cpu_before_top.log
        ├── cpu_strace_app.log
        ├── cpu_strace_signal.log
        ├── deadlock_before_app.log
        ├── deadlock_after_app.log
        ├── deadlock_before_monitor.log
        ├── deadlock_after_monitor.log
        ├── deadlock_before_ps.log
        ├── deadlock_before_threads.log
        └── deadlock_before_topH.log
```

`logs/` 디렉터리는 테스트 중 생성되는 원본 로그 저장 위치이며 GitHub에는 업로드하지 않았다. 대신 제출에 필요한 로그는 `evidence/logs/`에 정리하여 업로드하였다.

---

## 6. 리포트 목록

본 프로젝트는 세 가지 장애 유형에 대해 GitHub Issue 형식의 기술 리포트를 작성하였다.

* `reports/oom.md`
* `reports/cpu-spike.md`
* `reports/deadlock.md`

각 리포트는 다음 구조를 따른다.

1. Description (현상 설명)
2. Evidence & Logs (증거 자료)
3. Root Cause Analysis (원인 분석)
4. Workaround & Verification (조치 및 검증)

---

## 7. OOM / Memory Leak 분석 요약

OOM 테스트에서는 `MEMORY_LIMIT` 값을 조정하여 메모리 누수와 MemoryGuard 동작을 비교하였다.

Before 조건은 다음과 같다.

```bash
MEMORY_LIMIT=100
CPU_MAX_OCCUPY=20
MULTI_THREAD_ENABLE=false
```

Before 실행에서는 `MemoryWorker`의 Heap 사용량이 증가하다가 제한값에 도달하자 다음과 같은 로그가 출력되었다.

```text
Memory limit exceeded
Self-terminating process
```

After 조건은 다음과 같다.

```bash
MEMORY_LIMIT=300
CPU_MAX_OCCUPY=20
MULTI_THREAD_ENABLE=false
```

After 실행에서는 메모리 사용량이 증가하더라도 캐시 정리 동작이 수행되며 다음과 같은 로그가 확인되었다.

```text
Memory Usage Reached Limit
Memory Cache Flushed
MEMORY RECOVERED
```

이를 통해 `MEMORY_LIMIT` 값을 높이면 프로세스가 즉시 종료되지 않고 더 오래 생존하며, 내부 정리 로직이 동작할 수 있음을 확인하였다.

관련 증거 파일은 다음과 같다.

* `evidence/logs/oom_before_app.log`
* `evidence/logs/oom_before_monitor.log`
* `evidence/logs/oom_after_app.log`
* `evidence/logs/oom_after_monitor.log`

---

## 8. CPU Spike 분석 요약

CPU Spike 테스트에서는 `CPU_MAX_OCCUPY` 값을 조정하여 CPU 과점유 상황과 보호 동작을 비교하였다.

Before 조건은 다음과 같다.

```bash
MEMORY_LIMIT=512
CPU_MAX_OCCUPY=80
MULTI_THREAD_ENABLE=false
```

Before 실행에서는 앱 로그에서 다음과 같은 CPU 관련 경고와 임계치 초과 로그가 확인되었다.

```text
CPU Limit: 80% [ WARNING: Recommend Under 50% ]
CpuWorker Started. Maximum CPU Limit: 80%
CPU Threshold Violated
```

일반 앱 로그에는 `WATCHDOG` 문구가 직접적으로 출력되지는 않았지만, `strace -e trace=signal`을 추가로 사용하여 프로세스 종료 신호를 확인하였다. `strace` 결과에서는 다음과 같이 `SIGTERM` 종료가 확인되었다.

```text
tgkill(382, 382, SIGTERM) = 0
--- SIGTERM {si_signo=SIGTERM, si_code=SI_TKILL, si_pid=382, si_uid=1001} ---
+++ killed by SIGTERM +++
```

이는 CPU threshold violation 이후 프로세스가 Linux 신호인 `SIGTERM`에 의해 종료되었음을 보여준다. 따라서 해당 종료는 단순 오류가 아니라 CPU 과점유 감지 이후 보호 동작으로 발생한 종료로 판단하였다.

After 조건은 다음과 같다.

```bash
MEMORY_LIMIT=512
CPU_MAX_OCCUPY=50
MULTI_THREAD_ENABLE=false
```

After 실행에서는 CPU 부하가 peak에 도달한 뒤 cooldown 동작으로 전환되었고, Before와 같은 threshold violation 종료는 발생하지 않았다.

```text
CPU Limit: 50% [ OK ]
Peak reached
Starting cooldown
Cooldown complete
```

관련 증거 파일은 다음과 같다.

* `evidence/logs/cpu_before_app.log`
* `evidence/logs/cpu_before_monitor.log`
* `evidence/logs/cpu_before_ps.log`
* `evidence/logs/cpu_before_top.log`
* `evidence/logs/cpu_after_app.log`
* `evidence/logs/cpu_after_monitor.log`
* `evidence/logs/cpu_strace_app.log`
* `evidence/logs/cpu_strace_signal.log`

---

## 9. Deadlock 분석 요약

Deadlock 테스트에서는 `MULTI_THREAD_ENABLE` 값을 조정하여 멀티스레드 환경에서 발생하는 자원 대기 상태를 재현하고 회피하였다.

Before 조건은 다음과 같다.

```bash
MEMORY_LIMIT=512
CPU_MAX_OCCUPY=20
MULTI_THREAD_ENABLE=true
```

Before 실행에서는 프로세스가 종료되지 않고 PID가 유지되었지만, 로그상으로 worker thread들이 서로의 자원을 기다리는 상태가 발생하였다.

```text
SYSTEM WARNING: POTENTIAL DEADLOCK IN CONCURRENT MODE
LOCK ACQUIRED
WAITING
BLOCKED
```

`ps -ef` 결과를 통해 프로세스가 살아 있음을 확인하였고, `ps -L` 및 `top -H` 결과를 통해 스레드/프로세스 상태를 추가로 확인하였다. 이는 프로세스가 종료된 것이 아니라 살아있는 상태에서 진행이 멈춘 무응답 상태임을 보여준다.

After 조건은 다음과 같다.

```bash
MEMORY_LIMIT=512
CPU_MAX_OCCUPY=20
MULTI_THREAD_ENABLE=false
```

After 실행에서는 멀티스레드 실행을 비활성화하여 자원 경쟁을 제거했고, 작업이 정상적으로 완료되었다.

```text
Concurrency: False
SYSTEM STATUS: STABLE
ALL CONFIGURATIONS OPTIMAL
All tasks completed
```

관련 증거 파일은 다음과 같다.

* `evidence/logs/deadlock_before_app.log`
* `evidence/logs/deadlock_before_monitor.log`
* `evidence/logs/deadlock_before_ps.log`
* `evidence/logs/deadlock_before_threads.log`
* `evidence/logs/deadlock_before_topH.log`
* `evidence/logs/deadlock_after_app.log`
* `evidence/logs/deadlock_after_monitor.log`

---

## 10. 사용한 주요 명령어 및 도구

본 프로젝트에서 사용한 주요 Linux 도구는 다음과 같다.

| 도구                       | 사용 목적                                       |
| :----------------------- | :------------------------------------------ |
| `monitor.sh`             | 프로세스 실행 여부, 포트 상태, CPU/MEM/RSS 상태를 주기적으로 기록 |
| `ps`                     | 프로세스 존재 여부 및 PID 확인                         |
| `top`                    | 프로세스 단위 CPU/MEM 사용률 확인                      |
| `ps -L`                  | 스레드 단위 상태 확인                                |
| `top -H`                 | 스레드 단위 CPU/MEM 상태 확인                        |
| `strace -e trace=signal` | CPU Spike 케이스에서 SIGTERM 종료 여부 확인            |
| `timeout`                | 테스트 실행 시간을 제한하여 실험 반복성 확보                   |

`strace`는 CPU Spike 케이스에서 추가 증거로 사용하였다. 앱 로그가 `CPU Threshold Violated`까지만 보여주었기 때문에, Linux 신호 수준에서 실제 종료 방식이 `SIGTERM`인지 확인하기 위해 사용하였다.

---

## 11. GitHub 업로드 제외 파일

제공 바이너리와 실행 중 생성되는 민감 파일 또는 임시 파일은 GitHub에 업로드하지 않았다.

제외한 파일 및 디렉터리는 다음과 같다.

* `agent-app-leak`
* `agent-app-leak.zip`
* `agent-leak-app-x86`
* `agent-leak-app-arm64`
* `__MACOSX/`
* `api_keys/`
* `upload_files/`
* `logs/`

제출용 증거 로그는 `evidence/logs/`에 정리하여 업로드하였다.

---

## 12. Clone 후 재현 시 주의사항

이 저장소에는 과제에서 제공된 실행 바이너리와 zip 파일을 포함하지 않았다. 따라서 저장소를 clone한 뒤 실습을 재현하려면 과제에서 제공받은 `agent-app-leak.zip` 파일을 프로젝트 루트에 직접 넣어야 한다.

예시:

```bash
cp ~/Downloads/agent-app-leak.zip ./agent-app-leak.zip
```

이후 Docker 컨테이너 내부에서 압축을 해제하고, CPU 아키텍처에 맞는 실행 파일을 선택해야 한다.

```bash
unzip -o agent-app-leak.zip

ARCH="$(uname -m)"

if [ "$ARCH" = "x86_64" ]; then
  cp agent-leak-app-x86 agent-app-leak
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  cp agent-leak-app-arm64 agent-app-leak
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

chmod +x agent-app-leak monitor.sh
```

실제 제출 저장소는 실행 재현용 바이너리 저장소가 아니라, 장애 분석 리포트와 증거 로그를 정리한 제출용 저장소이다.

---

## 13. 결론

본 실습을 통해 단순히 프로세스가 종료되거나 멈춘 결과만 확인하는 것이 아니라, 로그와 시스템 관제 데이터를 근거로 장애 원인을 추론하는 과정을 수행하였다.

OOM은 Heap 사용량 증가와 MemoryGuard 로그를 통해 메모리 제한 초과에 따른 자가 종료로 판단하였다. CPU Spike는 CpuWorker의 부하 증가, CPU Threshold Violated 로그, 그리고 `strace`를 통한 SIGTERM 종료 확인을 통해 CPU 과점유 보호 동작으로 판단하였다. Deadlock은 PID가 유지되는 상태에서 WAITING/BLOCKED 로그와 스레드 상태를 통해 교착상태로 판단하였다.

최종적으로 세 장애 모두 환경변수 조정을 통해 Before & After를 비교하였고, 각 결과를 GitHub Issue 형식의 리포트로 정리하였다.
