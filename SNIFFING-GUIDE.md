# Di2 BLE 스니핑 가이드 — 실제 UUID / 기어 포맷 찾기

이 데이터필드의 BLE 배관(스캔 → 페어링 → 프로파일 → notify 구독 → 파싱 → 표시)은
완성돼 있습니다. 하지만 Shimano Di2의 BLE(E-TUBE) 프로토콜은 **비공개**라,
아래 3개 값은 본인 자전거에서 직접 캡처해 채워 넣어야 실제로 기어가 표시됩니다.

채워야 할 값 (`source/Di2BleManager.mc` 상단):

| 상수 | 의미 |
|------|------|
| `SERVICE_UUID`   | 기어 상태를 노출하는 128비트 GATT 서비스 UUID |
| `GEAR_CHAR_UUID` | 현재 기어 위치를 notify 하는 characteristic UUID |
| `NAME_MATCH`     | 스캔 결과에서 Di2 유닛을 식별할 광고 이름 일부 |

그리고 `_parseGear()`의 바이트 오프셋을 실제 캡처 포맷에 맞게 조정합니다.

---

## 준비물

- Di2 장착 자전거 (무선 유닛 또는 EW-RS 무선 모듈이 BLE 광고 중이어야 함)
- 스마트폰 BLE 스캐너 앱: **nRF Connect** (Nordic, iOS/Android 무료) 권장
- 주의: E-TUBE / Garmin 등 다른 앱이 Di2에 **이미 연결돼 있으면** 스니핑이 막힙니다.
  스니핑 동안에는 그 앱들에서 Di2 연결을 끊어두세요.

---

## 1단계 — 광고 이름 찾기 (`NAME_MATCH`)

1. 자전거 Di2를 깨웁니다 (아무 변속 버튼 한 번).
2. nRF Connect → **SCANNER** 탭에서 스캔.
3. 변속 버튼을 누를 때 RSSI가 출렁이는 기기를 찾습니다. 보통 이름이
   `SHIMANO …` 형태입니다.
4. 그 정확한 이름의 고정된 앞부분을 `NAME_MATCH`에 넣습니다 (예: `"SHIMANO"`).
   - 이름이 안 뜨면 광고의 **Service UUID** 또는 **Manufacturer Data**(Shimano
     회사 ID)로 매칭하도록 `onScanResults()`를 바꿔야 합니다 — 그 경우 알려주세요.

## 2단계 — 서비스 / characteristic UUID 찾기 (`SERVICE_UUID`, `GEAR_CHAR_UUID`)

1. 그 기기를 **CONNECT**.
2. GATT 서비스 목록이 뜹니다. 표준 서비스(Generic Access `1800`, Device
   Info `180a`, Battery `180f`)는 무시하고, **128비트 커스텀 서비스**(긴 UUID,
   `0000xxxx-...` 가 아닌 것)를 펼칩니다 — 보통 여기에 기어 데이터가 있습니다.
3. 그 서비스 안의 각 characteristic에서 **Notify/Indicate** 속성이 있는 것을 찾아
   알림을 켭니다 (특성 옆 ↓↓ 또는 다중 화살표 아이콘 탭).
4. 변속 버튼을 눌러 보세요. 값이 바뀌는 characteristic이 **기어 characteristic**
   입니다.
   - 그 서비스의 UUID → `SERVICE_UUID`
   - 그 characteristic의 UUID → `GEAR_CHAR_UUID`
   - UUID는 `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` 형식 그대로 넣습니다.

## 3단계 — 바이트 포맷 알아내기 (`_parseGear`)

1. 2단계에서 notify를 켠 상태로, 기어를 **한 칸씩** 바꾸며 매번 hex 값을 기록합니다.
2. 어느 바이트가 어떻게 변하는지 매핑합니다. 예시 관찰:

   ```
   리어 1단:  02 0B 01 0B 00
   리어 2단:  02 0B 02 0B 00   ← 3번째 바이트(index 2)가 리어 인덱스
   프론트 변속: 01 0B 02 0B 00  ← 1번째 바이트(index 0)가 프론트 인덱스
   ```

   위 경우라면 `_parseGear`는 이미 맞습니다(front=value[0], rear=value[2]).
   다르면 오프셋을 실제에 맞게 수정하세요. max 단수가 별도 바이트로 오면
   `frontMax`/`rearMax`도 그 오프셋으로 잡습니다.
3. 비트로 packing 돼 있으면(예: 한 바이트에 front+rear) `& 0x0F`, `>> 4` 등으로
   분리합니다.

## 4단계 — 채워 넣고 빌드

1. `source/Di2BleManager.mc`의 세 상수와 `_parseGear`를 수정.
2. 빌드 후 실기기에 사이드로드(아래 README/명령 참고).
3. 데이터필드가 "Di2 검색중…" → (연결되면) 실제 기어 숫자로 바뀌면 성공.

---

## 참고

- 표시는 페어링한 톱니수 테이블(`GearConfig` / 앱 설정의 `frontTeeth`,
  `rearTeeth`)을 인덱스로 조회해 변환합니다. 인덱스만 정확히 캡처되면 톱니수는
  설정에서 맞추면 됩니다.
- 12단 무선 Di2(R9200/R8100)와 구형 유선+EW-WU 무선 모듈은 광고 이름/포맷이
  다를 수 있습니다. 본인 시스템 기준으로 캡처하세요.
