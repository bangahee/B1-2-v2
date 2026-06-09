# [Bug] CPU Spike - CPU 과점유 설정으로 인한 보호 동작

## 1. Description (현상 설명)

`CPU_MAX_OCCUPY=80`으로 설정하고 애플리케이션을 실행하면 `CpuWorker`의 CPU 부하가 점진적으로 증가하였다. 애플리케이션은 80% 설정을 위험한 값으로 판단하여 경고를 출력하였고, 이후 CPU 부하가 임계 구간에 도달하면서 `CPU Threshold Violated` 로그가 발생하였다.

일반 애플리케이션 로그에서는 `WATCHDOG` 문구가 직접적으로 출력되지는 않았지만, `strace -e trace=signal`을 통해 프로세스가 최종적으로 `SIGTERM` 신호에 의해 종료되었음을 확인하였다. 따라서 본 CPU Spike 케이스는 단순 오류가 아니라 CPU 과점유 감지 이후 보호 동작에 의해 프로세스가 종료된 사례로 판단하였다.

## 2. Evidence & Logs (증거 자료)

확인한 증거 파일은 다음과 같다.

* `evidence/logs/cpu_before_app.log`
* `evidence/logs/cpu_before_monitor.log`
* `evidence/logs/cpu_before_ps.log`
* `evidence/logs/cpu_before_top.log`
* `evidence/logs/cpu_after_app.log`
* `evidence/logs/cpu_after_monitor.log`
* `evidence/logs/cpu_strace_app.log`
* `evidence/logs/cpu_strace_signal.log`
* `evidence/logs/cpu_strace_monitor.log`

Before 실행에서는 다음 로그가 확인되었다.

```text
CPU Limit: 80% [ WARNING: Recommend Under 50% ]
CpuWorker Started. Maximum CPU Limit: 80%
CPU Threshold Violated
```

또한 `strace -e trace=signal` 실행 결과, CPU threshold violation 이후 프로세스가 `SIGTERM`에 의해 종료된 것이 확인되었다.

```text
tgkill(382, 382, SIGTERM) = 0
--- SIGTERM {si_signo=SIGTERM, si_code=SI_TKILL, si_pid=382, si_uid=1001} ---
+++ killed by SIGTERM +++
```

After 실행에서는 다음 로그가 확인되었다.

```text
CPU Limit: 50% [ OK ]
Peak reached
Starting cooldown
Cooldown complete
```

`ps`, `top`, `monitor.sh` 로그를 통해 CPU Spike가 시스템 전체 문제가 아니라 `agent-app-leak` 프로세스에서 발생한 부하임을 확인하였다.

## 3. Root Cause Analysis (원인 분석)

CPU 사용률이 계속 증가하면 단일 프로세스가 시스템 자원을 과도하게 점유하여 전체 시스템 응답성을 저하시킬 수 있다. 이 애플리케이션은 CPU 과점유를 방지하기 위해 `CpuWorker` 또는 Watchdog 성격의 보호 로직을 포함하고 있으며, 위험한 CPU 설정 또는 임계치 초과가 감지되면 보호 동작을 수행한다.

`CPU_MAX_OCCUPY=80`은 프로그램 기준에서 권장값을 초과한 위험 설정이므로 경고가 출력되었고, 실제 실행 중 CPU 부하가 증가하며 `CPU Threshold Violated`가 발생하였다. 이후 `strace` 결과에서 `SIGTERM` 신호가 확인되었으므로, 프로세스 종료는 단순한 실행 실패가 아니라 CPU 과점유 감지 이후 프로세스 보호를 위한 종료 동작으로 볼 수 있다.

운영체제 관점에서 `SIGTERM`은 프로세스에 종료를 요청하는 신호이다. 따라서 이 케이스에서는 CPU 부하가 임계 구간에 도달했고, 애플리케이션 또는 내부 보호 로직이 프로세스를 종료시키는 흐름으로 이어졌다고 분석할 수 있다.

## 4. Workaround & Verification (조치 및 검증)

임시 조치로 `CPU_MAX_OCCUPY` 값을 80에서 50으로 낮추었다.

| 구분         | 설정                  | 결과                                                |
| :--------- | :------------------ | :------------------------------------------------ |
| **Before** | `CPU_MAX_OCCUPY=80` | CPU 경고, `CPU Threshold Violated`, `SIGTERM` 종료 확인 |
| **After**  | `CPU_MAX_OCCUPY=50` | CPU peak 이후 cooldown 동작, threshold violation 없음   |

따라서 CPU 제한값을 권장 범위로 낮추면 CPU 부하가 일정 수준까지 상승한 뒤 cooldown 상태로 전환되며, CPU 과점유로 인한 비정상적인 보호 종료 동작을 피할 수 있음을 확인하였다.

근본적인 해결을 위해서는 애플리케이션 내부에서 CPU 부하를 유발하는 반복 작업이나 연산 로직을 최적화하고, 과도한 busy-wait 또는 무한 루프성 작업이 존재하는지 점검해야 한다.
