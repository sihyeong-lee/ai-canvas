# AI Canvas 오류 운영 가이드 (최신 단일본)

최종 업데이트: 2026-03-05  
적용 범위: Step1 노드 1~21 + Worker 재시도 프록시
연관 문서: `manual.md`, `retry_proxy_setup.md`

## 1) 운영 원칙

1. 전체 재실행 금지, 실패 노드만 재시도
2. 목록 API는 반드시 `6 -> 7 -> 8` 순차 실행
3. 본문 API(12~14)는 `*_detail_url` 확인 후 실행
4. 차단 응답은 노드18/19 조건부터 확인
5. 반복 장애면 Worker 재시도 프록시 적용

## 2) 고정 제약

1. Python 중간 코드에 `import`, `return`, `yield`, `re.compile(` 금지
2. 일부 런타임에서 `chr`, `format`, `hasattr` 제한 가능
3. `query` 인코딩 1회만 허용
   - 허용: `query=징계` 또는 `query=%EC...`
   - 금지: `query=%25EC...`
4. `OC=tud1211` 고정

## 3) 오류 코드 표 (운영용)

| 코드 | 증상 | 주원인 | 즉시 조치 |
|---|---|---|---|
| E-001 | `Not allowed context: import json` | 중간 코드 import 사용 | import 제거 |
| E-002 | `Not allowed context: return or yield` | 중간 코드 return/yield 사용 | `result = ...` 방식으로 변경 |
| E-003 | `name 'chr' is not defined` | 제한 런타임 built-in 차단 | chr 미사용 로직으로 교체 |
| E-004 | `name 'format' is not defined` | 제한 런타임 built-in 차단 | format 미사용 문자열 조합 |
| E-005 | `name 'hasattr' is not defined` | 제한 런타임 built-in 차단 | hasattr 없는 분기 로직 |
| E-006 | `Not allowed context: compile(` | re.compile 사용 | compile 없는 정규식/문자열 처리 |
| E-007 | `sequence item 0: expected str instance, NoneType found` | API 노드 method/header/body/url None | 빈 행 제거 + `api_method/api_headers_json/api_body` 고정 |
| E-008 | `비정상적인 URL이 포함되어 있습니다` | detail URL 빈값/깨짐 | 노드9~11 출력 URL 점검 후 12~14 실행 |
| E-009 | 상세 URL 빈값 | 목록 응답 구조(blob) 파싱 실패 | 노드9~11 최신 파싱 코드 적용 |
| E-010 | `[Errno 104] Connection reset by peer` | 외부 API 일시 불안정 | 실패 노드만 재시도 + Worker 적용 |
| E-011 | 노드21 응답 미노출 | 타깃 컬럼 선택 오류 | `output_response*`만 선택 |
| E-012 | 근거통합 노드 빨간불 | 상류 red로 입력 단절 | 목록 3개 성공 후 다음 단계 진행 |
| E-013 | 유용 질문도 차단됨 | 게이트 정책 과도 | query_class 기반 게이트 사용 |
| E-014 | API 간헐 실패/깨진 URL | query 이중 인코딩 | `%25EC...` 제거, 인코딩 1회 원칙 |

## 4) 게이트 기준 (노드18)

1. `legal_analysis`: 답변 텍스트가 있고 금지 도메인 아니면 통과
2. `internal_db_only`: `internal_evidence_count >= 1` + 텍스트 존재 + 금지 도메인 아님
3. `mixed`: `official_evidence_count >= 1` 또는 `internal_evidence_count >= 1` + 텍스트 존재 + 금지 도메인 아님

## 5) 차단문구 오동작 체크 (노드19/20)

1. 노드18에서 `is_pass` 실제 값 확인 (`true/false`)
2. 노드19 조건값 오타 확인 (`ture` 금지)
3. 노드20 변수는 `{{fail_reason}}` 사용
4. 노드21은 참 분기/거짓 분기 컬럼 모두 점검

## 6) 재시도 운영 플로우

1. 노드6 실패 -> 노드6만 1~2회 재시도
2. 노드7/8 동일 방식 적용
3. 반복 실패 시 Worker 적용
4. Worker 적용 후에도 502 반복이면 upstream 장애로 판단

## 7) Worker 적용 기준

다음 중 1개라도 해당하면 Worker 적용 권장:
1. 같은 URL이 수동 재실행에서만 간헐 성공
2. 하루 3회 이상 `[Errno 104]` 발생
3. 목록 API red가 연쇄적으로 본문/통합까지 막음

## 8) 종료 전 체크리스트

1. 노드9/10/11의 `*_detail_url` 비어있지 않음
2. 노드12/13/14 응답 행 존재
3. 노드18 `query_class_final`, `is_pass`, `fail_reason` 확인
4. 노드19 분기 정상
5. 노드21 최종 응답 컬럼 정상

## 9) 로그 템플릿 (복붙)

```text
[YYYY-MM-DD HH:mm] 케이스명:
- 입력:
- 실패 노드:
- 에러 메시지:
- 원인 추정:
- 조치:
- 재실행 결과:
- 다음 예방 조치:
```
