# [Bug] OOM Crash - 메모리 제한 초과로 인한 프로세스 자가 종료

## 1. Description (현상 설명)

`agent-app-leak` 실행 중 `MemoryWorker`의 Heap 사용량이 시간에 따라 지속적으로 증가하였다. `MEMORY_LIMIT=100`으로 설정했을 때 Heap 사용량이 제한값에 도달하자 애플리케이션 내부의 MemoryGuard가 동작하며 프로세스가 자가 종료되었다.

## 2. Evidence & Logs (증거 자료)

확인한 증거 파일은 다음과 같다.

- `evidence/logs/oom_before_app.log`
- `evidence/logs/oom_before_monitor.log`
- `evidence/logs/oom_after_app.log`
- `evidence/logs/oom_after_monitor.log`

Before 실행에서는 다음 로그가 확인되었다.

```text
MemoryWorker Current Heap 증가
Memory limit exceeded
Self-terminating process
```

After 실행에서는 다음 로그가 확인되었다.

```text
Memory Usage Reached Limit
Memory Cache Flushed
MEMORY RECOVERED (Cache Cleared)
```

## 3. Root Cause Analysis (원인 분석)
Heap 메모리 사용량이 반복적으로 증가하는 것으로 보아 애플리케이션 내부에서 메모리를 계속 점유하는 작업이 수행되고 있었다. MEMORY_LIMIT=100에서는 제한값에 빠르게 도달하여 MemoryGuard가 시스템 불안정을 방지하기 위해 프로세스를 종료하였다.
이는 운영체제가 직접 종료한 것이 아니라, 애플리케이션 내부 보호 정책이 메모리 제한 초과를 감지하고 자가 종료한 것으로 판단된다.

## 4. Workaround & Verification (조치 및 검증)
임시 조치로 MEMORY_LIMIT 값을 100에서 300으로 증가시켰다.

| 구분 | 설정 | 결과 |
| :--- | :--- | :--- |
| **Before** | MEMORY_LIMIT=100 | Memory limit exceeded 발생 후 프로세스 종료 |
| **After** | MEMORY_LIMIT=300 | Memory Cache Flushed 후 프로세스 안정화 |

따라서 메모리 제한을 높이면 프로세스가 즉시 종료되지 않고, 캐시 정리 과정을 통해 더 오래 실행될 수 있음을 확인하였다. 다만 근본적인 해결을 위해서는 애플리케이션 내부의 메모리 사용 로직 수정이 필요하다.
