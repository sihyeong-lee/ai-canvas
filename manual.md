# AI Canvas 구축 매뉴얼 v2 동기화본 (Step1 운영 + 내부DB 확장)

기준 문서: `step1.md`, `act.md`

## 1) 목적과 범위
- 이 문서는 Step1 운영 안정화와 v2 확장(내부DB 결합) 방향을 함께 다룹니다.
- Step1 기본 경로는 내부 DB 없이 동작합니다.
- v2 확장 시 내부 DB(`Cases`, `Evidence_Facts`, `Facts` 또는 API/CSV)를 결합합니다.
- `노동법 RAG` PDF는 AI Canvas에 업로드하지 않습니다.
- 법령/판례/행정해석은 외부 API로만 조회합니다.

## 2) 고정 규칙
- 모든 API URL에 `OC=tud1211`를 포함합니다.
- 커스텀 API 노드에는 `OC` 입력칸이 없으므로 URL 쿼리에 직접 넣습니다.
- 공식근거가 1건 이상이면 가능한 범위에서 답변하고, 0건일 때만 차단합니다.

## 3) Step1 기본 노드 목록 (현행)
1. 에이전트
2. 에이전트 메시지 가로채기
3. 에이전트 프롬프트_질의정규화
4. 파이썬_정규화파싱
5. 파이썬_URL생성
6. API_법령목록
7. API_판례목록
8. API_해석목록
9. 파이썬_법령상세URL
10. 파이썬_판례상세URL
11. 파이썬_해석상세URL
12. API_법령본문
13. API_판례본문
14. API_해석본문
15. 데이터 연결_근거통합1 (법령+판례)
16. 데이터 연결_근거통합2 (근거통합1+해석)
17. 에이전트 프롬프트_답변생성
18. 파이썬_검열게이트
19. 데이터 조건 분기
20. 프롬프트_차단응답
21. 에이전트로 전달

## 3-2) v2 확장 노드 (내부DB 결합 시 추가)
22. API_내부징계DB조회 (또는 데이터셋_내부징계DB)
23. 파이썬_근거표준화 (외부/내부 근거를 공통 스키마로 정리)
24. 파이썬_근거스코어링 (근거 우선순위/신뢰도 점수화)

## 4) 정확한 포트 연결 맵
| From 노드 | From 포트/컬럼 | To 노드 | To 포트/컬럼 |
|---|---|---|---|
| 에이전트 | 메시지 출력 | 에이전트 메시지 가로채기 | 메시지 입력 |
| 에이전트 메시지 가로채기 | 가로챈 메시지 | 에이전트 프롬프트_질의정규화 | 프롬프트 입력 |
| 에이전트 프롬프트_질의정규화 | `normalized_json` | 파이썬_정규화파싱 | 입력 데이터셋 |
| 파이썬_정규화파싱 | `issue_keywords_csv`,`law_query`,`precedent_query`,`interpretation_query`,`date_from`,`date_to`,`must_have` | 파이썬_URL생성 | 입력 데이터셋 |
| 파이썬_URL생성 | `law_list_url` | API_법령목록 | URL 컬럼 |
| 파이썬_URL생성 | `prec_list_url` | API_판례목록 | URL 컬럼 |
| 파이썬_URL생성 | `expc_list_url` | API_해석목록 | URL 컬럼 |
| API_법령목록 | 목록 결과(`ID`,`MST` 포함) | 파이썬_법령상세URL | 입력 데이터셋 |
| API_판례목록 | 목록 결과(`ID`) | 파이썬_판례상세URL | 입력 데이터셋 |
| API_해석목록 | 목록 결과(`ID`) | 파이썬_해석상세URL | 입력 데이터셋 |
| 파이썬_법령상세URL | `law_detail_url` | API_법령본문 | URL 컬럼 |
| 파이썬_판례상세URL | `prec_detail_url` | API_판례본문 | URL 컬럼 |
| 파이썬_해석상세URL | `expc_detail_url` | API_해석본문 | URL 컬럼 |
| API_법령본문 | 본문 결과 | 데이터 연결_근거통합1 | 입력1 |
| API_판례본문 | 본문 결과 | 데이터 연결_근거통합1 | 입력2 |
| 데이터 연결_근거통합1 | 중간 통합셋 | 데이터 연결_근거통합2 | 입력1 |
| API_해석본문 | 본문 결과 | 데이터 연결_근거통합2 | 입력2 |
| 데이터 연결_근거통합2 | 통합 근거셋 | 에이전트 프롬프트_답변생성 | 프롬프트 컨텍스트 |
| (v2) API_내부징계DB조회/데이터셋_내부징계DB | 내부 사례/규정 데이터 | 파이썬_근거표준화 | 입력2 |
| (v2) 데이터 연결_근거통합2 | 외부 통합 근거셋 | 파이썬_근거표준화 | 입력1 |
| (v2) 파이썬_근거표준화 | 표준 근거셋 | 파이썬_근거스코어링 | 입력 데이터셋 |
| (v2) 파이썬_근거스코어링 | 우선순위 반영 근거셋 | 에이전트 프롬프트_답변생성 | 프롬프트 컨텍스트 |
| 에이전트 프롬프트_답변생성 | `output_response` (환경에 따라 `draft_answer`) + `source_urls`, `official_evidence_count` | 파이썬_검열게이트 | 입력 데이터셋 |
| 파이썬_검열게이트 | `is_pass`,`fail_reason`,`official_evidence_count` | 데이터 조건 분기 | 조건 입력(`is_pass == true`) |
| 데이터 조건 분기(참) | `output_response` (없으면 `draft_answer`) | 에이전트로 전달 | 응답 입력 |
| 데이터 조건 분기(거짓) | 분기 트리거 | 프롬프트_차단응답 | 프롬프트 입력 |
| 프롬프트_차단응답 | `output_response_1` (환경에 따라 `output_response`) | 에이전트로 전달 | 응답 입력 |

## 5) 프롬프트 원문
### 노드 3: 에이전트 프롬프트_질의정규화
```text
역할: 징계 사건 입력을 공식 검색용 구조로 정규화
반드시 JSON만 출력
스키마:
{
  "case_type": "",
  "issue_keywords": [""],
  "law_query": "",
  "precedent_query": "",
  "interpretation_query": "",
  "incident_date": "YYYY-MM-DD 또는 빈 문자열",
  "date_from": "YYYYMMDD 또는 빈 문자열",
  "date_to": "YYYYMMDD 또는 빈 문자열",
  "must_have": ["법령명","조문","시행일","법원","선고일","사건번호"]
}
규칙:
- 사용자 입력 의미를 바꾸지 말 것
- `issue_keywords`는 빈 값 금지(최소 1개)
- `law_query`, `precedent_query`, `interpretation_query` 중 최소 1개는 채울 것
- 정보가 부족하면 기본값 `징계` 사용
- 키워드는 3~7개 권장(최소 1개)
```

### 노드 17: 에이전트 프롬프트_답변생성
```text
역할: 근거 기반 징계 검토 보고서 작성
금지: 근거에 없는 단정, 출처 없는 결론
반드시 아래 템플릿을 제목/순서/아이콘/기호까지 그대로 사용
정보가 없으면 빈칸 대신 반드시 `부재`라고 기재
링크는 원문 URL만 허용
법령 1개 + 판례/해석 1개 이상 없으면 `♟️ 종합 판단` 작성 금지
Step1에서는 내부DB를 연결하지 않으므로 `🏢 내부DB 참고`는 기본적으로 `부재`로 기재
근거가 일부만 있어도(예: 1건) 가능한 범위의 일반 요건/입증 포인트를 작성하고,
부족한 부분은 `[불확실/부재]`에 명시합니다.

[🟢 Online Mode | {timestamp}] >
🔍 Search Strategy >
> {수집 전략 요약}
> [🌐 웹 서치 적용: {도메인 목록}]

🧊 사실관계 요약
- {사용자 진술 요약}
- {불명확 포인트}

⚖️ 쟁점
- {쟁점1}
- {쟁점2}

📚 적용 법령
- 법령명: {name}
- 조문: {article}
- 시행일: {effective_date}
- 해석 포인트: {point}

🧑‍⚖️ 관련 판례
- 법원: {court}
- 선고일: {date}
- 사건번호: {case_no}
- 판시요지: {holding}
- 근거 링크: {url}

🏢 내부DB 참고
- 사내 규정: {rule_name}
- 유사 징계사례: {case_id / 요약}
- 차이점: {difference}

♟️ 종합 판단
- {종합 의견}

🚀 다음 액션
- {필요 증거}
- {문서/절차}
- {기한}

[불확실/부재]
- {근거 부족 항목 명시}
```

### 노드 20: 프롬프트_차단응답
```text
다음 3줄을 반드시 포함해 한국어로 짧게 답변하세요.
1) 현재 조회된 공식근거가 없어 결론을 제시하지 않습니다
2) 추가 사실/기간/키워드가 필요합니다
3) 불확실/부재 항목: {fail_reason}
```

## 6) 커스텀 API 노드 설정 (노드 6~8, 12~14)
### 6-1. 공통 설정값
- 노드 유형: `API > 커스텀 API`
- 요청 모드: `데이터셋 요청`
- Method: `GET`
- URL 입력 방식: `URL 컬럼`
- Request Body: 사용 안 함
- Header: 기본값(없음)
- 응답 변환: `JSON -> CSV` 켬

UI가 다른 버전일 때:
- `데이터셋 요청`에서 Method 항목이 잠겨 `GET`으로 보이면 정상입니다.
- 핵심은 `URL 컬럼`이 정확히 선택되어 있는지입니다.
- 화면에 `selected method column / selected headers column / selected body column`이 보이는 버전이면 비우지 말고 아래 컬럼을 연결:
  - method: `api_method`
  - headers: `api_headers_json`
  - body: `api_body`

### 6-2. 목록 API (노드 6~8) 설정
| 노드 | URL 컬럼(입력) | 연결 원본 | 목적 |
|---|---|---|---|
| `API_법령목록` | `law_list_url` | 노드5 출력 | 법령 목록 조회 |
| `API_판례목록` | `prec_list_url` | 노드5 출력 | 판례 목록 조회 |
| `API_해석목록` | `expc_list_url` | 노드5 출력 | 해석례 목록 조회 |

노드 6~8 실행 후 최소 점검:
- 결과 행이 1건 이상인지 확인
- `API_법령목록` 결과에 `법령ID/MST`가 있거나 `LawSearch:law` blob 컬럼이 있는지 확인
- `API_판례목록`, `API_해석목록` 결과에 `id/ID`가 있거나 `PrecSearch:prec`/`Expc:expc` blob 컬럼이 있는지 확인
- UI가 method/header/body 컬럼을 요구하면 모두 노드5의 `api_*` 컬럼으로 연결했는지 확인

### 6-3. 본문 API (노드 12~14) 설정
| 노드 | URL 컬럼(입력) | 연결 원본 | 목적 |
|---|---|---|---|
| `API_법령본문` | `law_detail_url` | 노드9 출력 | 법령 본문 조회 |
| `API_판례본문` | `prec_detail_url` | 노드10 출력 | 판례 본문 조회 |
| `API_해석본문` | `expc_detail_url` | 노드11 출력 | 해석 본문 조회 |

노드 12~14 실행 후 최소 점검:
- URL 컬럼이 빈 문자열이 아닌지
- 응답 컬럼에 본문/요지 계열 값이 들어왔는지
- 3개 노드 결과가 모두 노드15로 연결되어 있는지
- UI가 method/header/body 컬럼을 요구하면 모두 노드9~11의 `api_*` 컬럼으로 연결했는지 확인

### 6-4. API URL 고정 기준값 (참조)
- 법령 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=eflaw&type=JSON`
- 법령 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&type=JSON`
- 판례 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=prec&type=JSON`
- 판례 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&type=JSON`
- 해석례 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=expc&type=JSON`
- 해석례 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&type=JSON`

### 6-5. 자주 나는 실수와 복구 순서
1. 노드 6~8이 비어 있음
- 노드5 출력에서 `law_list_url/prec_list_url/expc_list_url` 값부터 확인
- 커스텀 API 노드가 `단일 요청`으로 바뀌지 않았는지 확인 (`데이터셋 요청`이어야 함)
- URL의 `query`가 `징계 관련 법령`처럼 길면 `징계`처럼 핵심어 1개로 줄여 재실행
2. 노드 12~14가 비어 있음
- 노드9~11 출력 URL(`*_detail_url`)이 실제로 생성됐는지 확인
- 노드12~14 `URL 컬럼` 선택이 올바른지 재확인
- 노드12~14에서 `selected method/header/body column`이 비어있지 않은지 확인 (`api_method/api_headers_json/api_body`)
- 목록 API 출력이 `LawSearch:law`, `PrecSearch:prec`, `Expc:expc`처럼 blob이면 노드9~11은 blob 파싱 버전 최신 코드여야 함
- 노드10/11은 `ID` 대신 `id`/`판례일련번호`/`법령해석례일련번호` 또는 `상세링크`에서 ID를 추출해야 함
3. `sequence item 0: expected str instance, NoneType found`
- 노드4 중간 코드 최신본으로 교체 후 재실행
4. 실행 순서
- `정규화파싱 -> URL생성 -> 목록API(6~8) -> 상세URL(9~11) -> 본문API(12~14) -> 근거통합1 -> 근거통합2 -> 답변생성 -> 검열게이트 -> 조건분기 -> 차단/전달`

### 6-6. `sequence item 0: expected str instance, NoneType found` 즉시 분리 진단
1. 노드6을 `단일 요청`으로 잠깐 바꿔 아래 URL을 직접 입력해 실행
- `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON&target=eflaw&search=1&query=%EC%A7%95%EA%B3%84&display=5&page=1&sort=ddes`
- 이게 성공하면 URL 자체 문제는 아님(데이터셋 바인딩/노드 옵션 문제)

2. 노드6 설정에서 아래 항목을 **완전히 비움**
- Header 행
- Query Parameter 행
- Body/폼 데이터 행
- 인증 항목
- 빈 행이 1줄이라도 남아 있으면 내부 join 과정에서 NoneType 에러가 날 수 있음

3. 다시 `데이터셋 요청` + `URL 컬럼(law_list_url)`로 복귀
- 같은 방식으로 노드7(`prec_list_url`), 노드8(`expc_list_url`)도 확인
- 노드5 출력 URL의 `query=` 값이 한글 그대로가 아니라 `%EC...` 형태(UTF-8 인코딩)인지 확인

4. 노드5 출력 행이 여러 개인 경우, 우선 최신 1행만 보내서 재검증
- 노드5 코드 상단에 임시로 아래 2줄 추가:
```python
if not df.empty:
    df = df.tail(1).copy()
```
- 에러가 사라지면 다중행 중 일부 행의 null/설정값이 원인

### 6-7. `[Errno 104] Connection reset by peer` 대응
의미:
- URL 문법 문제가 아니라, 요청 중 원격 서버가 연결을 강제로 끊은 상태
- 보통 네트워크 경로/보안장비/TLS 호환/요청 헤더 이슈

즉시 조치:
1. 커스텀 API 노드 Header를 아래 2개만 넣고 재시도
- `User-Agent: Mozilla/5.0`
- `Accept: application/json`
- 주의: Header/Query/Body에 **빈 행**이 있으면 제거

2. 노드 6/7/8을 동시에 실행하지 말고 한 개씩 순차 실행
- 트래픽 급증으로 연결 리셋이 반복되는지 확인

3. 같은 오류가 계속되면, AI Canvas 런타임에서 `law.go.kr:443` 아웃바운드가 막힌 상태일 수 있음
- 네트워크/보안 담당에 도메인 허용 요청: `www.law.go.kr`
- 필요 시 API 중계 프록시(사내/클라우드) 경유로 호출

### 6-9. 목록 API가 "되다/안되다" 반복될 때 (실전 규칙)
관측된 패턴:
- 동일 URL 연속 호출 시 대부분 성공하지만 첫 호출에서 간헐적으로 연결 리셋이 발생할 수 있음
- 재실행 시 정상 통과되는 경우가 많음(외부 API 일시 불안정)

운영 규칙:
1. 노드 6~8은 반드시 순차 실행 (`6 -> 7 -> 8`)
2. 실패 시 전체 재실행하지 말고 실패 노드만 1~2회 재시도
3. 테스트 단계에서는 입력 행을 1행으로 제한 후 안정화 확인
4. `selected method/header/body column`은 항상 `api_method/api_headers_json/api_body` 고정
5. 노드 9~11에서 `*_detail_url` 빈 값 여부 확인 후 12~14 실행

관리자 문의가 필요한 경우:
- 30분 이상 지속적으로 전 노드 실패
- 같은 URL 단일 호출도 반복적으로 `403/429/연결실패`
- 재시도 3회 이상에도 동일 증상이 계속될 때

### 6-10. 목록 API 일부 실패 시 근거통합이 멈추는 이유
증상:
- 예: `API_법령목록`, `API_판례목록` 실패 + `API_해석목록` 성공
- `API_해석본문`만 성공하고 `데이터 연결_근거통합1`이 빨간불로 중단

원인:
- `데이터 연결` 노드는 상류 입력이 모두 정상 데이터셋이어야 연결 가능
- 목록/API 노드가 red 상태면 하위 입력 포트로 데이터셋이 전달되지 않아 연쇄 중단

즉시 운영 규칙(현행 Step1):
1. 목록 단계(6~8) 3개가 모두 성공하기 전에는 9~14, 근거통합 단계를 실행하지 않음
2. 실패 시 전체 재실행 대신 실패 노드만 재시도
3. 재시도 순서: `6 -> 7 -> 8` (각 1~2초 간격)

v2 권장(부분 성공 허용):
1. `파이썬_근거표준화` 노드에서 성공한 소스만 모아 표준 스키마로 변환
2. 공식근거(`is_official=true`)가 1건 이상이면 답변 생성 경로 유지
3. 공식근거 0건일 때만 차단 경로로 분기
4. 내부DB는 없어도 답변 생성, 있으면 `내부DB 참고` 섹션을 보강

### 6-11. 워밍업 호출(선택, 간헐 오류 완화)
목적:
- 첫 호출에서만 연결 리셋이 나는 패턴을 줄이기 위한 사전 호출

방법:
1. 임시 커스텀 API 노드(단일 요청) 1개 생성
2. URL:
- `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON&target=eflaw&search=1&query=%EC%A7%95%EA%B3%84&display=1&page=1&sort=ddes`
3. Header:
- `User-Agent: Mozilla/5.0`
- `Accept: application/json`
4. 워크플로우 실행 시, 목록 API(6~8) 전에 이 노드를 1회 실행

주의:
- 워밍업은 장애를 100% 제거하지는 않으며, 근본 해결은 중계 API(재시도 내장) 구조임

### 6-8. 데이터 조건 분기(노드 18) 설정
연결:
- 입력 데이터셋: 노드17(`파이썬_검열게이트`) 출력
- 참(True) 출력: 노드21(`에이전트로 전달`)로 연결
- 거짓(False) 출력: 노드20(`프롬프트_차단응답`)로 연결

조건식(권장 1개):
- Left/컬럼: `is_pass`
- Operator/연산자: `equals` 또는 `==`
- Right/값: 불리언 `true`

UI가 텍스트 값만 받는 경우:
- 1순위: `True`
- 2순위: `true`
- 3순위: `1`

노드21 최종 응답 매핑:
- 참 분기: `output_response`를 응답 입력으로 사용 (없으면 `draft_answer`)
- 거짓 분기: `output_response_1`를 응답 입력으로 사용 (환경에 따라 `output_response`)
- `question_prompt`/`question_response` 계열 컬럼은 선택하지 않음

컬럼명이 자동으로 `_1`, `_2`처럼 붙는 경우:
- 규칙: **최종 답변 텍스트가 담긴 `output_response*` 컬럼만 선택**
- 예시:
  - 참 경로 컬럼: `output_response`
  - 거짓 경로 컬럼: `output_response_1`

분기 점검 체크리스트:
- 노드17 데이터보기에서 `is_pass`가 행마다 존재하는지 확인
- `is_pass=True`인 행은 노드21으로 바로 전달되는지 확인
- `is_pass=False`인 행은 노드20을 거쳐 차단 메시지로 전달되는지 확인

## 7) Python 노드 코드 (AI Canvas 고정 스캐폴드 전용)
중요: AI Canvas Python 노드는 아래 형식의 상/하단이 고정이며, **`execute()` 함수 내부만 입력 가능**합니다.
주의: 일부 환경에서는 중간 코드에 `def`, `return`, `yield`가 있으면 실행이 차단됩니다. 아래 중간 코드는 해당 키워드 없이 작성했습니다.

```python
import math
import random
import datetime
import collections
import itertools
import json
import re
import csv
import sklearn      # 1.3.2
import pandas as pd # 1.4.3
import numpy as np  # 1.23.1
import oracledb
import pyodbc
import mariadb
import psycopg2

def execute(
        x: List[pd.DataFrame],
        dataset: pd.DataFrame
) -> pd.DataFrame:
    # 여기만 입력 가능
    ...
    return result
```

아래 코드는 모두 **`execute()` 내부에만 붙여넣는 코드**입니다.

### 노드 4: 파이썬_정규화파싱 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

if "normalized_json" in df.columns:
    source_col = "normalized_json"
elif "output_response" in df.columns:
    source_col = "output_response"
else:
    source_col = None

rows = []
for row in df.to_dict(orient="records"):
    raw = row.get(source_col, "") if source_col else ""
    obj = {}

    if isinstance(raw, dict):
        obj = raw
    else:
        text = "" if raw is None else str(raw).strip()
        if text and text.lower() != "nan":
            try:
                obj = json.loads(text)
            except Exception:
                m = re.search(r"\{.*\}", text, re.S)
                if m:
                    try:
                        obj = json.loads(m.group(0))
                    except Exception:
                        obj = {}

    kws = obj.get("issue_keywords", [])
    if isinstance(kws, str):
        kws = [x.strip() for x in re.split(r"[,\s/|]+", kws) if x.strip()]
    elif isinstance(kws, list):
        cleaned = []
        for x in kws:
            if x is None:
                continue
            sx = str(x).strip()
            if sx and sx.lower() != "nan":
                cleaned.append(sx)
        kws = cleaned
    else:
        kws = []

    law_query = obj.get("law_query", "")
    if law_query is None:
        law_query = ""
    else:
        try:
            if pd.isna(law_query):
                law_query = ""
        except Exception:
            pass
    law_query = str(law_query).strip()
    if law_query.lower() == "nan":
        law_query = ""

    precedent_query = obj.get("precedent_query", "")
    if precedent_query is None:
        precedent_query = ""
    else:
        try:
            if pd.isna(precedent_query):
                precedent_query = ""
        except Exception:
            pass
    precedent_query = str(precedent_query).strip()
    if precedent_query.lower() == "nan":
        precedent_query = ""

    interpretation_query = obj.get("interpretation_query", "")
    if interpretation_query is None:
        interpretation_query = ""
    else:
        try:
            if pd.isna(interpretation_query):
                interpretation_query = ""
        except Exception:
            pass
    interpretation_query = str(interpretation_query).strip()
    if interpretation_query.lower() == "nan":
        interpretation_query = ""

    if not kws:
        fallback = " ".join([law_query, precedent_query, interpretation_query]).strip()
        if not fallback:
            for k in ["question", "query", "user_query", "user_input", "input_text", "message", "agent_message", "chat_message", "content", "text"]:
                v = row.get(k, "")
                if v is None:
                    v = ""
                else:
                    try:
                        if pd.isna(v):
                            v = ""
                    except Exception:
                        pass
                v = str(v).strip()
                if v.lower() == "nan":
                    v = ""
                if v and not v.startswith("{"):
                    fallback = v
                    break
        if fallback:
            toks = [t for t in re.split(r"[,\s/|]+", fallback) if t]
            kws = []
            for t in toks:
                st = str(t).strip()
                if st and st.lower() != "nan" and len(st) >= 2:
                    kws.append(st)
                if len(kws) >= 7:
                    break

    if not kws:
        kws = ["징계"]

    seed = " ".join(kws[:3]).strip() or "징계"
    if not law_query:
        law_query = seed
    if not precedent_query:
        precedent_query = seed
    if not interpretation_query:
        interpretation_query = seed

    must_have = obj.get("must_have", [])
    if isinstance(must_have, str):
        must_have = [x.strip() for x in must_have.split(",") if x.strip()]
    elif isinstance(must_have, list):
        cleaned = []
        for x in must_have:
            if x is None:
                continue
            sx = str(x).strip()
            if sx and sx.lower() != "nan":
                cleaned.append(sx)
        must_have = cleaned
    else:
        must_have = []
    if not must_have:
        must_have = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]

    date_from = obj.get("date_from", "")
    if date_from is None:
        date_from = ""
    else:
        try:
            if pd.isna(date_from):
                date_from = ""
        except Exception:
            pass
    date_from = str(date_from).strip()
    if date_from.lower() == "nan":
        date_from = ""

    date_to = obj.get("date_to", "")
    if date_to is None:
        date_to = ""
    else:
        try:
            if pd.isna(date_to):
                date_to = ""
        except Exception:
            pass
    date_to = str(date_to).strip()
    if date_to.lower() == "nan":
        date_to = ""

    rows.append({
        "issue_keywords_csv": ", ".join(kws),
        "law_query": law_query,
        "precedent_query": precedent_query,
        "interpretation_query": interpretation_query,
        "date_from": date_from,
        "date_to": date_to,
        "must_have": ",".join(must_have),
    })

result = pd.DataFrame(rows, columns=[
    "issue_keywords_csv",
    "law_query",
    "precedent_query",
    "interpretation_query",
    "date_from",
    "date_to",
    "must_have",
])
```

### 노드 5: 파이썬_URL생성 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()
base = "https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON"

rows = []
for _, r in df.iterrows():
    fallback = r.get("issue_keywords_csv", "")
    if fallback is None:
        fallback = ""
    else:
        try:
            if pd.isna(fallback):
                fallback = ""
        except Exception:
            pass
    fallback = str(fallback).strip()
    if fallback.lower() == "nan" or not fallback:
        fallback = "징계"

    lq = r.get("law_query", "")
    if lq is None:
        lq = ""
    else:
        try:
            if pd.isna(lq):
                lq = ""
        except Exception:
            pass
    lq = str(lq).strip()
    if lq.lower() == "nan" or not lq:
        lq = fallback

    pq = r.get("precedent_query", "")
    if pq is None:
        pq = ""
    else:
        try:
            if pd.isna(pq):
                pq = ""
        except Exception:
            pass
    pq = str(pq).strip()
    if pq.lower() == "nan" or not pq:
        pq = fallback

    eq = r.get("interpretation_query", "")
    if eq is None:
        eq = ""
    else:
        try:
            if pd.isna(eq):
                eq = ""
        except Exception:
            pass
    eq = str(eq).strip()
    if eq.lower() == "nan" or not eq:
        eq = fallback

    # API 검색 안정화: "징계 관련 법령" 같은 문구를 핵심 키워드로 축약
    stopwords = set([
        "관련", "법령", "판례", "해석", "행정해석", "문의", "질문", "검토",
        "찾아줘", "알려줘", "해주세요", "요청", "자료", "내용"
    ])

    work = lq.replace(",", " ").replace("/", " ").replace("|", " ")
    parts = [p.strip() for p in work.split() if p.strip()]
    core = [p for p in parts if p not in stopwords and len(p) >= 2]
    if core:
        lq = core[0]
    elif parts:
        lq = parts[0]
    if not lq:
        lq = "징계"

    work = pq.replace(",", " ").replace("/", " ").replace("|", " ")
    parts = [p.strip() for p in work.split() if p.strip()]
    core = [p for p in parts if p not in stopwords and len(p) >= 2]
    if core:
        pq = core[0]
    elif parts:
        pq = parts[0]
    if not pq:
        pq = "징계"

    work = eq.replace(",", " ").replace("/", " ").replace("|", " ")
    parts = [p.strip() for p in work.split() if p.strip()]
    core = [p for p in parts if p not in stopwords and len(p) >= 2]
    if core:
        eq = core[0]
    elif parts:
        eq = parts[0]
    if not eq:
        eq = "징계"

    # UTF-8 퍼센트 인코딩(한글 포함, chr 미사용)

    hexmap = "0123456789ABCDEF"

    lq_enc = ""
    for b in lq.encode("utf-8"):
        if 48 <= b <= 57:
            lq_enc += "0123456789"[b - 48]
        elif 65 <= b <= 90:
            lq_enc += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[b - 65]
        elif 97 <= b <= 122:
            lq_enc += "abcdefghijklmnopqrstuvwxyz"[b - 97]
        elif b == 45:
            lq_enc += "-"
        elif b == 46:
            lq_enc += "."
        elif b == 95:
            lq_enc += "_"
        elif b == 126:
            lq_enc += "~"
        elif b == 32:
            lq_enc += "%20"
        else:
            lq_enc += "%" + hexmap[b // 16] + hexmap[b % 16]

    pq_enc = ""
    for b in pq.encode("utf-8"):
        if 48 <= b <= 57:
            pq_enc += "0123456789"[b - 48]
        elif 65 <= b <= 90:
            pq_enc += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[b - 65]
        elif 97 <= b <= 122:
            pq_enc += "abcdefghijklmnopqrstuvwxyz"[b - 97]
        elif b == 45:
            pq_enc += "-"
        elif b == 46:
            pq_enc += "."
        elif b == 95:
            pq_enc += "_"
        elif b == 126:
            pq_enc += "~"
        elif b == 32:
            pq_enc += "%20"
        else:
            pq_enc += "%" + hexmap[b // 16] + hexmap[b % 16]

    eq_enc = ""
    for b in eq.encode("utf-8"):
        if 48 <= b <= 57:
            eq_enc += "0123456789"[b - 48]
        elif 65 <= b <= 90:
            eq_enc += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[b - 65]
        elif 97 <= b <= 122:
            eq_enc += "abcdefghijklmnopqrstuvwxyz"[b - 97]
        elif b == 45:
            eq_enc += "-"
        elif b == 46:
            eq_enc += "."
        elif b == 95:
            eq_enc += "_"
        elif b == 126:
            eq_enc += "~"
        elif b == 32:
            eq_enc += "%20"
        else:
            eq_enc += "%" + hexmap[b // 16] + hexmap[b % 16]

    rows.append({
        "law_query_used": lq,
        "prec_query_used": pq,
        "expc_query_used": eq,
        "law_list_url": f"{base}&target=eflaw&search=1&query={lq_enc}&display=5&page=1&sort=ddes",
        "prec_list_url": f"{base}&target=prec&search=1&query={pq_enc}&display=5&page=1&sort=ddes",
        "expc_list_url": f"{base}&target=expc&search=1&query={eq_enc}&display=5&page=1&sort=ddes",
        "api_method": "GET",
        "api_headers_json": "{\"User-Agent\":\"Mozilla/5.0\",\"Accept\":\"application/json\"}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=[
    "law_query_used",
    "prec_query_used",
    "expc_query_used",
    "law_list_url",
    "prec_list_url",
    "expc_list_url",
    "api_method",
    "api_headers_json",
    "api_body",
])
```

### 노드 9: 파이썬_법령상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    idv = ""
    for k in ["법령ID", "law_id", "id", "ID"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                idv = v
                break

    mstv = ""
    for k in ["MST", "mst", "법령MST", "법령일련번호"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                mstv = v
                break

    efyd = ""
    for k in ["시행일자", "efYd"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                efyd = re.sub(r"\D", "", v)[:8]
                break

    link = ""
    for k in ["법령상세링크", "detail_link", "링크"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                link = v
                break

    law_blob = row.get("LawSearch:law", "")
    if (law_blob is None) or (str(law_blob).strip() == ""):
        law_blob = row.get("law", "")
    if (law_blob is None) or (str(law_blob).strip() == ""):
        for kk in row.keys():
            sk = str(kk)
            if sk.lower().endswith(":law"):
                law_blob = row.get(kk, "")
                break

    law_text = "" if law_blob is None else str(law_blob).strip()
    if law_text and law_text.lower() != "nan":
        arr = []
        try:
            arr = json.loads(law_text)
        except Exception:
            t = law_text.replace("None", "null").replace("True", "true").replace("False", "false")
            t = t.replace("'", "\"")
            try:
                arr = json.loads(t)
            except Exception:
                arr = []

        if isinstance(arr, dict):
            arr = [arr]

        if isinstance(arr, list) and len(arr) > 0 and isinstance(arr[0], dict):
            d = arr[0]

            if not idv:
                v = d.get("법령ID", d.get("ID", ""))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    idv = v

            if not mstv:
                v = d.get("MST", d.get("법령일련번호", ""))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    mstv = v

            if not efyd:
                v = d.get("시행일자", d.get("efYd", ""))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    efyd = re.sub(r"\D", "", v)[:8]

            if not link:
                v = d.get("법령상세링크", d.get("detail_link", ""))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    link = v

    if link:
        if link.startswith("/"):
            link = "https://www.law.go.kr" + link
        if "?" in link:
            q = link.split("?", 1)[1]
            for part in q.split("&"):
                if "=" in part:
                    kk, vv = part.split("=", 1)
                    if (not mstv) and kk.upper() == "MST":
                        mstv = vv
                    if (not idv) and kk.upper() == "ID":
                        idv = vv
                    if (not efyd) and kk == "efYd":
                        efyd = re.sub(r"\D", "", vv)[:8]

    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    mstv_enc = mstv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    efyd_enc = efyd.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")

    if mstv and efyd:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={mstv_enc}&efYd={efyd_enc}&type=JSON"
    elif mstv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={mstv_enc}&type=JSON"
    elif idv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&ID={idv_enc}&type=JSON"
    else:
        url = ""

    rows.append({
        "law_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{\"User-Agent\":\"Mozilla/5.0\",\"Accept\":\"application/json\"}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["law_detail_url", "api_method", "api_headers_json", "api_body"])
```

### 노드 10: 파이썬_판례상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    idv = ""
    for k in ["id", "ID", "판례정보일련번호", "판례일련번호", "prec_id"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                idv = v
                break

    link = ""
    for k in ["판례상세링크", "detail_link", "링크"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                link = v
                break

    prec_blob = row.get("PrecSearch:prec", "")
    if (prec_blob is None) or (str(prec_blob).strip() == ""):
        prec_blob = row.get("prec", "")
    if (prec_blob is None) or (str(prec_blob).strip() == ""):
        for kk in row.keys():
            sk = str(kk)
            if sk.lower().endswith(":prec"):
                prec_blob = row.get(kk, "")
                break

    prec_text = "" if prec_blob is None else str(prec_blob).strip()
    if prec_text and prec_text.lower() != "nan":
        arr = []
        try:
            arr = json.loads(prec_text)
        except Exception:
            t = prec_text.replace("None", "null").replace("True", "true").replace("False", "false")
            t = t.replace("'", "\"")
            try:
                arr = json.loads(t)
            except Exception:
                arr = []

        if isinstance(arr, dict):
            arr = [arr]

        if isinstance(arr, list) and len(arr) > 0 and isinstance(arr[0], dict):
            d = arr[0]

            if not link:
                v = d.get("판례상세링크", d.get("상세링크", d.get("detail_link", "")))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    link = v

            if not idv:
                v = d.get("id", d.get("ID", d.get("판례정보일련번호", d.get("판례일련번호", ""))))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    idv = v

    if link:
        if link.startswith("/"):
            link = "https://www.law.go.kr" + link
        if "?" in link:
            q = link.split("?", 1)[1]
            for part in q.split("&"):
                if "=" in part:
                    kk, vv = part.split("=", 1)
                    if kk.upper() == "ID" and (not idv):
                        idv = vv

    if idv.endswith(".0"):
        head = idv[:-2]
        only_num = True
        if not head:
            only_num = False
        else:
            for ch in head:
                if ch < "0" or ch > "9":
                    only_num = False
                    break
        if only_num:
            idv = head

    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({
        "prec_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{\"User-Agent\":\"Mozilla/5.0\",\"Accept\":\"application/json\"}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["prec_detail_url", "api_method", "api_headers_json", "api_body"])
```

### 노드 11: 파이썬_해석상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    idv = ""
    for k in ["id", "ID", "행정해석ID", "법령해석례일련번호", "expc_id"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                idv = v
                break

    link = ""
    for k in ["법령해석례상세링크", "detail_link", "링크"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                link = v
                break

    expc_blob = row.get("Expc:expc", "")
    if (expc_blob is None) or (str(expc_blob).strip() == ""):
        expc_blob = row.get("expc", "")
    if (expc_blob is None) or (str(expc_blob).strip() == ""):
        for kk in row.keys():
            sk = str(kk)
            if sk.lower().endswith(":expc"):
                expc_blob = row.get(kk, "")
                break

    expc_text = "" if expc_blob is None else str(expc_blob).strip()
    if expc_text and expc_text.lower() != "nan":
        arr = []
        try:
            arr = json.loads(expc_text)
        except Exception:
            t = expc_text.replace("None", "null").replace("True", "true").replace("False", "false")
            t = t.replace("'", "\"")
            try:
                arr = json.loads(t)
            except Exception:
                arr = []

        if isinstance(arr, dict):
            arr = [arr]

        if isinstance(arr, list) and len(arr) > 0 and isinstance(arr[0], dict):
            d = arr[0]

            if not link:
                v = d.get("법령해석례상세링크", d.get("상세링크", d.get("detail_link", "")))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    link = v

            if not idv:
                v = d.get("id", d.get("ID", d.get("행정해석ID", d.get("법령해석례일련번호", ""))))
                v = "" if v is None else str(v).strip()
                if v and v.lower() != "nan":
                    idv = v

    if link:
        if link.startswith("/"):
            link = "https://www.law.go.kr" + link
        if "?" in link:
            q = link.split("?", 1)[1]
            for part in q.split("&"):
                if "=" in part:
                    kk, vv = part.split("=", 1)
                    if kk.upper() == "ID" and (not idv):
                        idv = vv

    if idv.endswith(".0"):
        head = idv[:-2]
        only_num = True
        if not head:
            only_num = False
        else:
            for ch in head:
                if ch < "0" or ch > "9":
                    only_num = False
                    break
        if only_num:
            idv = head

    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({
        "expc_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{\"User-Agent\":\"Mozilla/5.0\",\"Accept\":\"application/json\"}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["expc_detail_url", "api_method", "api_headers_json", "api_body"])
```

### 노드 17: 파이썬_검열게이트 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

allow_hosts = (
    "law.go.kr",
    "open.law.go.kr",
    "portal.scourt.go.kr",
    "ecfs.scourt.go.kr",
)
must_slots = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    draft = row.get("draft_answer", row.get("output_response", ""))
    if draft is None:
        draft = ""
    else:
        try:
            if pd.isna(draft):
                draft = ""
        except Exception:
            pass
    draft = str(draft).strip()
    if draft.lower() == "nan":
        draft = ""

    raw_urls = row.get("source_urls", "")
    urls = []
    if isinstance(raw_urls, list):
        for u in raw_urls:
            if u is None:
                continue
            try:
                if pd.isna(u):
                    continue
            except Exception:
                pass
            su = str(u).strip()
            if su and su.lower() != "nan":
                urls.append(su)
    else:
        text = raw_urls
        if text is None:
            text = ""
        else:
            try:
                if pd.isna(text):
                    text = ""
            except Exception:
                pass
        text = str(text).strip()
        if text.lower() == "nan":
            text = ""
        if text:
            if "|" in text:
                urls = [u.strip() for u in text.split("|") if u.strip()]
            else:
                tmp = text.replace("\n", " ").replace("\t", " ")
                tmp = tmp.replace(",", " ").replace(";", " ")
                tokens = [t for t in tmp.split(" ") if t]
                picked = []
                for t in tokens:
                    u = t.strip().strip("()[]{}<>\"'.,")
                    if u.startswith("http://") or u.startswith("https://"):
                        picked.append(u)
                urls = picked

    if not urls:
        tmp = draft.replace("\n", " ").replace("\t", " ")
        for sep in ["|", ",", ";", "(", ")", "[", "]", "{", "}", "<", ">", "\"", "'"]:
            tmp = tmp.replace(sep, " ")
        picked = []
        for t in tmp.split(" "):
            u = t.strip()
            if not u:
                continue
            if u.startswith("http://") or u.startswith("https://"):
                while len(u) > 0 and u[-1] in ".,)]}\"'":
                    u = u[:-1]
                if u:
                    picked.append(u)
        urls = picked

    norm_urls = []
    for u in urls:
        su = "" if u is None else str(u).strip()
        if not su:
            continue
        if su.lower() == "nan":
            continue
        exists = False
        for x in norm_urls:
            if x == su:
                exists = True
                break
        if not exists:
            norm_urls.append(su)
    urls = norm_urls

    official_urls = []
    for u in urls:
        ok = False
        for h in allow_hosts:
            if h in u:
                ok = True
                break
        if ok:
            official_urls.append(u)
    evidence = len(official_urls)
    raw_evidence = row.get("official_evidence_count", None)
    if raw_evidence is not None:
        try:
            evidence = int(raw_evidence)
        except Exception:
            evidence = len(official_urls)

    bad_domain = False
    if urls:
        for u in urls:
            ok = False
            for h in allow_hosts:
                if h in u:
                    ok = True
                    break
            if not ok:
                bad_domain = True
                break

    missing = []
    for s in must_slots:
        if s not in draft:
            missing.append(s)

    # 게이트 완화:
    # - 공식근거 1건 이상이면 답변 통과(부족 항목은 경고로만 기록)
    # - 공식근거 0건이거나 금지 도메인 포함 시에만 차단
    is_pass = (not bad_domain) and (evidence >= 1)

    reasons = []
    if evidence < 1:
        reasons.append("official_evidence_count<1")
    elif evidence < 2:
        reasons.append("official_evidence_count<2_warn")
    if bad_domain:
        reasons.append("domain_not_allowed")
    if missing:
        reasons.append("missing_slots:" + ",".join(missing))
    if not urls:
        reasons.append("source_urls_missing")

    row["is_pass"] = bool(is_pass)
    row["official_evidence_count"] = int(evidence)
    row["fail_reason"] = " / ".join(reasons) if reasons else ""
    rows.append(row)

result = pd.DataFrame(rows)
```

## 8) 초급자 실행 순서
1. 새 캔버스 생성 후 노드 1~21 배치.
2. 3개 프롬프트 노드(3,17,20)에 본문 그대로 붙여넣기.
3. Python 노드(4,5,9,10,11,18)는 **`execute()` 내부 중간 코드만** 붙여넣기.
4. API 노드(6,7,8,12,13,14)는 URL 컬럼 모드로 연결.
5. `OC=tud1211` 포함 여부를 6개 API URL 모두에서 확인.
6. 노드20/21 `Select target label`은 `output_response*`만 사용하고 `question_*`는 선택하지 않음.
7. 테스트 질의 10건 실행 후, `is_pass`와 차단응답 동작 확인.
8. v2 확장 시 노드 22~24를 추가하고, 답변 생성 입력을 `파이썬_근거스코어링` 출력으로 전환.

## 9) 주의사항
- Step1 기본 경로는 내부 DB 없이 운영하고, v2 확장 시 내부DB를 결합합니다.
- `노동법 RAG` PDF는 업로드하지 않습니다.
- 필요 정보는 API 재조회로만 채웁니다.

## 10) 테스트용 모델/토큰 권장값(전문형)
### 노드 3: 에이전트 프롬프트_질의정규화
- 모델: `gpt-5-mini`
- num response: `1`
- Max Output Tokens: `700` (권장 범위 `600~800`)
- Include Question Prompt In output: `OFF`
- Output column: `normalized_json`

### 노드 17: 에이전트 프롬프트_답변생성
- 모델: `gpt-5.2` (비용 절감 시 `gpt-5`)
- num response: `1`
- Max Output Tokens: `4500` (잘림 시 `6000~7000`)
- Include Question Prompt In output: `OFF`
- Output column: `output_response`

### 노드 20: 프롬프트_차단응답
- 모델: `gpt-5-nano` (안정성 우선 시 `gpt-4o-mini`)
- num response: `1`
- Max Output Tokens: `250` (권장 범위 `200~300`)
- Include Question Prompt In output: `OFF`
- Output column: `output_response` (중복 시 `output_response_1`)

## 11) 테스트 시나리오(실행용)
1. 정상 통과 케이스
- 입력 예시: `직장 내 괴롭힘 요건과 입증 포인트를 알려줘`
- 기대 결과: 노드18 `is_pass=True`, 노드21에서 `output_response` 전달

2. 경계 케이스(정보 부족)
- 입력 예시: `직장 내 괴롭힘인지 애매한데 판단해줘`
- 기대 결과: 공식근거가 1건 이상이면 통과하고, 부족 정보는 `[불확실/부재]`로 표시

3. 차단 유도 케이스
- 입력 예시: `검색 근거 없이 결론만 내줘`
- 기대 결과: 공식근거 0건이면 노드18 `is_pass=False`, 노드20 출력(`output_response_1` 또는 `output_response`)이 노드21로 전달

검증 체크:
- 노드 9/10/11의 `*_detail_url`이 빈 값이 아닌지
- 노드 12/13/14의 응답에 본문/요지 필드가 들어왔는지
- 노드 18의 `official_evidence_count`가 기대값(1 이상/0)과 일치하는지

## 12) v2 동기화 핵심 규칙
1. 하드 차단 조건
- 공식근거 0건
- 금지 도메인 포함

2. 소프트 통과 조건
- 공식근거 1건 이상이면 답변 생성
- 부족 정보는 `[불확실/부재]`에 명시

3. 근거 우선순위
- 법령 > 판례 > 행정해석 > 내부DB(보조)

4. 내부DB 사용 원칙
- 내부DB 단독으로 법적 결론을 내리지 않음
- 유사사례/양정 비교/사내 절차 설명에 사용

5. 표준 근거 스키마(권장 컬럼)
- `evidence_id`, `source_type`, `title`, `authority`, `date`, `key_point`, `quote`, `url`, `score`, `is_official`, `tags`


