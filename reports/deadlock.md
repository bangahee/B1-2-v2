# [Bug] Deadlock - 멀티스레드 환경에서 자원 대기로 인한 프로세스 무응답

## 1. Description (현상 설명)

`MULTI_THREAD_ENABLE=true`로 설정하고 애플리케이션을 실행하면 프로세스는 종료되지 않고 PID가 유지되지만, worker thread들이 서로의 자원을 기다리는 상태가 발생하였다. 로그상으로는 두 스레드가 각각 다른 자원을 먼저 점유한 뒤, 상대 스레드가 가진 자원을 요청하며 `WAITING` 및 `BLOCKED` 상태에 들어갔다.

## 2. Evidence & Logs (증거 자료)

확인한 증거 파일은 다음과 같다.

- `evidence/logs/deadlock_before_app.log`
- `evidence/logs/deadlock_before_monitor.log`
- `evidence/logs/deadlock_before_ps.log`
- `evidence/logs/deadlock_before_threads.log`
- `evidence/logs/deadlock_before_topH.log`
- `evidence/logs/deadlock_after_app.log`
- `evidence/logs/deadlock_after_monitor.log`

Before 실행에서는 다음 로그가 확인되었다.

```text
SYSTEM WARNING: POTENTIAL DEADLOCK IN CONCURRENT MODE
Worker-Thread-1 WAITING for Socket_Pool_B
Worker-Thread-2 WAITING for Shared_Memory_A
Status: BLOCKED
```

또한 `ps` 결과를 통해 프로세스 PID가 유지되고 있음을 확인하였다. 이는 프로세스가 종료된 것이 아니라 살아있는 상태에서 작업 진행이 멈춘 상태임을 보여준다.

## 3. Root Cause Analysis (원인 분석)
Deadlock은 여러 스레드가 서로 필요한 자원을 점유한 채 상대방의 자원 해제를 기다리면서 발생한다. 본 실행에서는 Worker-Thread-1이 Shared_Memory_A를 점유한 상태에서 Socket_Pool_B를 기다렸고, Worker-Thread-2는 Socket_Pool_B를 점유한 상태에서 Shared_Memory_A를 기다렸다.

따라서 다음 교착상태 조건이 충족된 것으로 판단된다.
- **상호 배제**: 하나의 자원을 한 스레드가 점유
- **점유 대기**: 이미 점유한 자원을 유지한 채 다른 자원을 기다림
- **비선점**: 다른 스레드가 가진 자원을 강제로 빼앗을 수 없음
- **순환 대기**: 두 스레드가 서로의 자원을 기다림

## 4. Workaround & Verification (조치 및 검증)
임시 조치로 MULTI_THREAD_ENABLE 값을 true에서 false로 변경하였다.

| 구분 | 설정 | 결과 |
| :--- | :--- | :--- |
| **Before** | MULTI_THREAD_ENABLE=true | WAITING/BLOCKED 로그 발생, 프로세스 무응답 |
| **After** | MULTI_THREAD_ENABLE=false | All tasks completed 로그 확인, Deadlock 재현되지 않음 |

멀티스레드 실행을 비활성화하자 스레드 간 자원 경쟁이 사라졌고, 작업이 순차적으로 완료되었다. 따라서 해당 장애는 concurrent mode에서 발생하는 스레드 간 자원 대기 문제로 판단된다.
