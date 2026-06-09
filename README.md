# B1-2: 리눅스 프로세스 및 시스템 리소스 트러블슈팅

## 1. 프로젝트 개요

본 프로젝트는 제공된 `agent-app-leak` 실행 파일을 Ubuntu 24.04 Docker 환경에서 실행하며 다음 세 가지 시스템 장애 상황을 재현하고 분석한 결과를 정리한 것이다.

1. OOM Crash / Memory Leak
2. CPU Spike / CPU 과점유
3. Deadlock / 교착상태

각 장애는 `monitor.sh`, 애플리케이션 실행 로그, `ps`, `top`, `ps -L` 등의 시스템 도구를 활용하여 관찰하였다. 최종 산출물은 GitHub Issue 형식의 기술 리포트와 증거 로그로 구성된다.

## 2. 실행 환경

- Docker image: `ubuntu:24.04`
- Container name: `B1-2-final-container`
- 실행 계정: `mission-user`
- 작업 디렉터리: `/app`
- 실행 파일: `agent-app-leak`
- 포트: `15034`
- 로그 디렉터리: `/app/logs`
- 업로드 디렉터리: `/app/upload_files`
- API key 디렉터리: `/app/api_keys`

## 3. 필수 환경변수

```bash
AGENT_HOME=/app
AGENT_LOG_DIR=/app/logs
AGENT_PORT=15034
AGENT_UPLOAD_DIR=/app/upload_files
AGENT_KEY_PATH=/app/api_keys
```

장애 유형별로 추가 환경변수를 변경하여 Before & After를 비교하였다.

## 4. 테스트별 환경변수 및 결과 요약

| 장애 유형 | Before 설정 | After 설정 | 확인 결과 |
| :--- | :--- | :--- | :--- |
| **OOM / Memory Leak** | MEMORY_LIMIT=100 | MEMORY_LIMIT=300 | Before에서는 MemoryGuard에 의해 종료, After에서는 Memory Cache Flushed 발생 |
| **CPU Spike** | CPU_MAX_OCCUPY=80 | CPU_MAX_OCCUPY=50 | Before에서는 CPU Threshold Violated 발생, After에서는 cooldown 동작 |
| **Deadlock** | MULTI_THREAD_ENABLE=true | MULTI_THREAD_ENABLE=false | Before에서는 WAITING/BLOCKED 발생, After에서는 task 정상 완료 |

## 5. 주요 파일 구조

```text
.
├── README.md
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
        ├── deadlock_before_app.log
        ├── deadlock_after_app.log
        ├── deadlock_before_monitor.log
        ├── deadlock_after_monitor.log
        ├── deadlock_before_ps.log
        ├── deadlock_before_threads.log
        └── deadlock_before_topH.log
```

## 6. 리포트 목록

- `reports/oom.md`
- `reports/cpu-spike.md`
- `reports/deadlock.md`

각 리포트는 다음 구조를 따른다.
1. Description
2. Evidence & Logs
3. Root Cause Analysis
4. Workaround & Verification

## 7. GitHub 업로드 제외 파일

제공 바이너리와 실행 중 생성되는 민감 파일은 업로드하지 않는다.
- `agent-app-leak`
- `agent-app-leak.zip`
- `api_keys/`
- `upload_files/`
- `logs/`

제출용 증거 로그는 `evidence/logs/`에 정리하여 업로드한다.

## 8. 결론

본 실습을 통해 단순히 프로세스가 종료되거나 멈춘 결과만 확인하는 것이 아니라, 로그와 시스템 관제 데이터를 근거로 장애 원인을 추론하는 과정을 수행하였다. OOM은 메모리 사용량 증가와 MemoryGuard 로그를 통해 확인하였고, CPU Spike는 CpuWorker의 부하 증가와 CPU Threshold Violated 로그를 통해 확인하였다. Deadlock은 PID가 유지되는 상태에서 WAITING/BLOCKED 로그와 스레드 상태를 통해 교착상태로 판단하였다.
