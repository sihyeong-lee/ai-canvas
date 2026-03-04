# AI Canvas 오류/운영 기록 v2 (error.md)

최종 업데이트: 2026-03-05
대상 프로젝트: 징계 챗봇 (Step1 운영 + v2 확장)
연관 문서: `manual.md`, `징계_챗봇_AI_Canvas_설계_v2.md`

## 1) 현재 운영 모드
### 1-1. Step1 현행 모드
- 노드 1~21 기준으로 운영.
- 외부 법령/판례/해석 API 중심.
- 목록 API(6~8) 실패 시 파이프라인 연쇄 중단 가능.

### 1-2. v2 확장 모드
- 노드 22~24 추가(`내부DB조회`, `근거표준화`, `근거스코어링`).
- 부분 성공 허용(성공한 근거만으로 답변 생성).
- 하드 차단은 `공식근거 0건` 또는 `금지 도메인`일 때만 적용.

## 2) 실행 환경 제약 (고정)
- Python 노드는 고정 스캐폴드에서 `execute()` 함수 중간 코드만 입력 가능.
- 일부 런타임에서 아래 문맥/내장 호출이 차단됨:
  - `import ...`
  - `return`, `yield`
  - `re.compile(...)`
  - 일부 built-in (`chr`, `format`, `hasattr` 등)
- 커스텀 API 노드는 UI 버전에 따라 `selected method/header/body column`이 비어 있으면 실패 가능.

## 3) 오류 이력 요약
| ID | 발생 노드 | 에러/증상 | 원인 | 즉시 조치 | 재발 방지 |
|---|---|---|---|---|---|
| E-001 | 노드4 | `Not allowed context: import json` | 중간 코드에 import 사용 | import 없는 코드로 교체 | 중간 코드에 import 금지 |
| E-002 | 노드4 | `Not allowed context: return or yield` | 중간 코드에 return/yield 사용 | `result = ...` 방식으로 변경 | return/yield 금지 |
| E-003 | 노드5 | `name 'chr' is not defined` | 제한 런타임에서 built-in 차단 | `chr` 미사용 인코딩 로직 적용 | built-in 의존 최소화 |
| E-004 | 노드5 | `name 'format' is not defined` | 제한 런타임에서 built-in 차단 | `format()` 제거 | format 대체 문자열 조합 |
| E-005 | 노드10/11 | `name 'hasattr' is not defined` | 제한 런타임에서 built-in 차단 | `hasattr` 없는 분기 로직으로 교체 | hasattr/inspect류 지양 |
| E-006 | 노드18(검열게이트) | `Not allowed context: compile(` | `re.compile()` 사용 | 컴파일 없는 URL 추출 로직으로 교체 | 정규식 사전컴파일 금지 |
| E-007 | 노드6~8,12~14 | `sequence item 0: expected str instance, NoneType found` | method/header/body 또는 URL 값에 None 포함 | `api_method/api_headers_json/api_body` 고정 매핑 + 빈 행 제거 | API 노드 템플릿 고정 |
| E-008 | 노드12~14 | `비정상적인 URL이 포함되어 있습니다` | `*_detail_url` 빈값/깨진값 | 노드9~11 URL 생성 로직 보강 | 본문 API 전 detail URL 사전 점검 |
| E-009 | 노드9~11 | detail URL 빈값 | API 결과가 blob(`LawSearch:law` 등) 형태 | blob 파싱 버전 코드 적용 | 목록 API 데이터보기로 컬럼 형태 확인 |
| E-010 | 노드6 | `[Errno 104] Connection reset by peer` | 외부 API 일시적 연결 리셋 | 실패 노드만 재시도 | 6→7→8 순차 실행 |
| E-011 | 노드21 전달 | 응답 컬럼 미노출(`draft_answer` 없음) | UI 컬럼명이 `output_response*` 체계 | `output_response`/`output_response_1` 선택 | `question_*` 컬럼 선택 금지 |
| E-012 | 근거통합1/2 | 목록 API 일부 실패 시 통합 노드 빨간불 | 상류 red 노드로 데이터셋 전달 끊김 | 목록 3개 성공 후 본문/통합 진행 | v2에서 부분 성공 허용 구조 도입 |
| E-013 | 노드18(검열게이트) | 과도 차단(유용 질문도 차단) | 과거 기준이 엄격(2건 미만 차단) | 게이트 정책 완화 | `evidence>=1` 통과 정책 유지 |

## 4) 게이트 정책 변경 이력
### 2026-03-05 변경
- 변경 전: `공식근거 2건 미만` 또는 슬롯 누락 시 차단
- 변경 후: `공식근거 1건 이상`이면 통과하고 부족 항목은 `[불확실/부재]`로 표기
- 하드 차단 조건:
  - `official_evidence_count == 0`
  - `domain_not_allowed == true`

## 5) Step1 운영 Runbook (즉시 대응)
1. 워밍업 호출 1회 실행
2. 목록 API 순차 실행: `6 -> 7 -> 8`
3. 실패 시 전체 재실행 금지, 실패 노드만 1~2회 재시도
4. 상세 URL 확인: `law_detail_url`, `prec_detail_url`, `expc_detail_url`
5. 본문 API 실행: `12 -> 13 -> 14`
6. 최종 전달 컬럼은 `output_response*`만 선택

## 6) v2 운영 규칙 (확장 모드)
1. 성공한 소스만 표준 Evidence 스키마로 변환해 통합
2. 공식근거 1건 이상이면 답변 생성 경로 유지
3. 내부DB가 비어도 답변 경로 유지
4. 내부DB는 법적 결론 단독 근거로 사용하지 않음(유사사례/양정 보조)

## 7) 모델 품질 이슈 정리
결론: `gpt-4o-mini`를 답변생성에 쓰면 품질 흔들림이 발생할 수 있음.
- 흔한 증상: 템플릿 누락, 법률 문맥 정밀도 저하, 긴 답변에서 근거 연결 약화

권장 모델:
1. 질의정규화(노드3): `gpt-5-mini`, max tokens `700`
2. 답변생성(노드17): `gpt-5.2`(또는 `gpt-5`), max tokens `4500` (필요 시 `6000~7000`)
3. 차단응답(노드20): `gpt-5-nano`, max tokens `250`

## 8) 관리자 문의 기준
아래 모두 해당할 때만 사이트/네트워크 담당 문의 권장:
1. 동일 URL 단일 호출이 30분 이상 지속 실패
2. 재시도 3회 이상에도 반복 실패
3. `403/429` 또는 연결 실패가 전 노드에서 지속 발생

그 외에는 대부분 외부 API 일시 불안정 또는 노드 설정/데이터 품질 문제로 현장 복구 가능.

## 9) 테스트 로그 템플릿 (복붙용)
```text
[YYYY-MM-DD HH:mm] 케이스명:
- 입력:
- 실패 노드:
- 에러 메시지:
- 즉시 조치:
- 재실행 결과:
- 재발 방지 반영:
```
