# AI Canvas 징계 챗봇 운영 매뉴얼 (최신 단일본)

최종 업데이트: 2026-03-05  
적용 범위: Step1 노드 1~21 (필수), Worker 재시도 프록시(권장)

## 0) 이 문서만 보면 되는 범위

- 이 문서는 현재 운영에 필요한 **최신 설정만** 남긴 단일 매뉴얼입니다.
- 구버전 기준(덧붙인 임시 규칙, 중복 섹션)은 제거했습니다.
- 기본 답변 경로는 1~21 노드입니다.

## 1) 고정 제약 (반드시 준수)

1. Python 노드는 고정 스캐폴드에서 `execute()` **중간 코드만** 입력
2. 중간 코드에 `import`, `return`, `yield`, `re.compile(` 금지
3. 일부 내장 함수(`chr`, `format`, `hasattr`) 제한 가능
4. 모든 법령 API 호출은 `OC=tud1211` 유지
5. 인코딩은 1회만 허용
   - 허용: `query=징계` 또는 `query=%EC...`
   - 금지: `query=%25EC...` (이중 인코딩)
6. 노드21(에이전트로 전달)은 `output_response*` 계열 컬럼만 선택

## 2) 노드 번호/역할 (1~21)

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

## 3) 노드별 핵심 설정 (복붙용)

### 노드 3: 에이전트 프롬프트_질의정규화

```text
역할: 징계/노무 질의를 검색 및 판정용 구조로 정규화
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
  "must_have": ["법령명","조문","시행일","법원","선고일","사건번호"],
  "query_class": "legal_analysis | internal_db_only | mixed",
  "internal_db_required": false
}

규칙:
- 사용자 의미를 바꾸지 말 것
- issue_keywords 최소 1개
- law_query / precedent_query / interpretation_query 중 최소 1개 채움
- 정보 부족 시 기본값은 `징계`
- 내부 통계/사내 DB 없이는 답 불가 질문이면 `internal_db_only`
- 일반 법률 판단/요건/입증 포인트 질문이면 `legal_analysis`
- 내부 사실 + 법률 검토 동시 필요면 `mixed`
```

### 노드 17: 에이전트 프롬프트_답변생성

```text
역할: 근거 기반 징계 검토 보고서 작성
금지: 근거 없는 단정, 가짜 출처 생성
반드시 아래 템플릿을 제목/순서/아이콘/기호까지 그대로 사용
링크는 원문 URL만 허용

출력 품질 규칙:
- `부재`를 기계적으로 반복하지 말 것
- 일반론 질의(요건/입증/적정성)에서는 구체 사실이 없어도 법리 기준/판단요소/입증 체크리스트를 충분히 작성
- 사실관계가 없으면 `🧊 사실관계 요약`에 문장으로 명시
- 판례 메타데이터가 없으면 임의 생성 금지, 대신 판례 법리 기준을 설명
- 내부DB 미연결이면 `🏢 내부DB 참고`는 "현재 Step1 모드에서는 내부DB 미연결"로 1회 표기
- `♟️ 종합 판단`은 조건부 판단(가능/주의/리스크)으로 작성
- 누락 정보는 `[불확실/부재]`에 모아 정리
- 최소 분량: `⚖️ 쟁점` 3개 이상, `📚 적용 법령` 2개 조문 이상, `🚀 다음 액션` 6개 이상

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
- {쟁점3}

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

### 노드 18: 검열게이트 정책 (현재 기준)

- `query_class=legal_analysis`
  - 통과 조건: 답변 텍스트 존재 + 금지 도메인 아님
- `query_class=internal_db_only`
  - 통과 조건: `internal_evidence_count >= 1` + 답변 텍스트 존재 + 금지 도메인 아님
- `query_class=mixed`
  - 통과 조건: `official_evidence_count >= 1` 또는 `internal_evidence_count >= 1` + 답변 텍스트 존재 + 금지 도메인 아님

### 노드 19: 데이터 조건 분기

- Left: `is_pass`
- Operator: `equals` (`==`)
- Right: `true`  (필요 시 `True`도 테스트)

연결:
- 참(True) -> 노드21
- 거짓(False) -> 노드20

### 노드 20: 프롬프트_차단응답

```text
다음 3줄을 반드시 포함해 한국어로 짧게 답변하세요.
1) 현재 조회된 공식근거가 없어 결론을 제시하지 않습니다
2) 추가 사실/기간/키워드가 필요합니다
3) 불확실/부재 항목: {{fail_reason}}
```

### 노드 21: 에이전트로 전달

- Select target label은 아래 중 실제 존재하는 응답 컬럼만 선택
  - `output_response`
  - `output_response_1`
- `question_*` 컬럼 선택 금지

## 4) Worker 재시도 프록시 적용 (권장)

목적: 목록/본문 API 간헐 오류를 자동 재시도로 흡수

사용 파일:
- `retry_proxy_cloudflare_worker.js`
- `retry_proxy_setup.md`

노드 5/9/10/11에서 공통으로 아래 값 사용:

```python
worker_base = "https://law-retry-proxy.<subdomain>.workers.dev"  # 실제 URL로 교체
if worker_base is None:
    worker_base = ""
worker_base = str(worker_base).strip()
if worker_base.endswith("/"):
    worker_base = worker_base[:-1]
```

노드 5 URL 생성(Worker 경유):

```python
law_list_url = f"{worker_base}/drf/search?target=eflaw&query={lq}&display=5&page=1&sort=ddes&oc=tud1211"
prec_list_url = f"{worker_base}/drf/search?target=prec&query={pq}&display=5&page=1&sort=ddes&oc=tud1211"
expc_list_url = f"{worker_base}/drf/search?target=expc&query={eq}&display=5&page=1&sort=ddes&oc=tud1211"
```

노드 9 상세 URL(Worker 경유):

```python
# mstv/idv 존재 여부에 따라 선택
url = f"{worker_base}/drf/detail?target=eflaw&MST={mstv_enc}&oc=tud1211"
# 또는
url = f"{worker_base}/drf/detail?target=eflaw&ID={idv_enc}&oc=tud1211"
```

노드 10 상세 URL(Worker 경유):

```python
url = f"{worker_base}/drf/detail?target=prec&ID={idv_enc}&oc=tud1211"
```

노드 11 상세 URL(Worker 경유):

```python
url = f"{worker_base}/drf/detail?target=expc&ID={idv_enc}&oc=tud1211"
```

## 5) 실행 순서 (운영 기준)

1. (권장) Worker `/health` 확인
2. 노드 3 -> 4 -> 5 실행
3. 노드 6 -> 7 -> 8 순차 실행
4. 노드 9 -> 10 -> 11 실행 후 `*_detail_url` 비어있지 않은지 확인
5. 노드 12 -> 13 -> 14 실행
6. 노드 15 -> 16 실행
7. 노드 17 -> 18 실행
8. 노드 19 분기 확인
9. 노드 21 응답 확인

재실행 원칙:
- 전체 재실행 금지
- 실패 노드만 1~2회 재시도

## 6) 자주 나는 오류와 즉시 조치

1. `sequence item 0: expected str instance, NoneType found`
- 원인: method/header/body/url 컬럼 중 None/빈 행
- 조치: API 노드의 불필요한 빈 행 제거, `api_method/api_headers_json/api_body` 매핑 고정

2. `[Errno 104] Connection reset by peer`
- 원인: 외부 API 일시 불안정
- 조치: 6->7->8 순차 실행 + 실패 노드 재시도, Worker 프록시 적용

3. `비정상적인 URL이 포함되어 있습니다`
- 원인: detail URL 빈값/깨짐
- 조치: 노드9~11 출력 먼저 확인 후 12~14 실행

4. 차단문구가 나오는데 통과여야 하는 경우
- 체크1: 노드18 `is_pass`가 실제로 `true`인지
- 체크2: 노드19 우변 값 오타(`ture`) 여부
- 체크3: 노드20 변수는 `{{fail_reason}}`인지

## 7) 테스트 시나리오 (최소 3건)

1. 일반 법률 질의
- 입력: `직장 내 괴롭힘 요건과 입증 포인트를 알려줘`
- 기대: `query_class=legal_analysis`, 노드18 `is_pass=true`, 내용형 답변

2. 내부DB 필수 질의
- 입력: `2025년 우리 회사 징계해고 건수 알려줘`
- 기대: 내부근거 없으면 `is_pass=false`, 차단응답

3. 혼합 질의
- 입력: `우리 회사 징계사례 기준으로 이번 건 양정 적정성 판단해줘`
- 기대: `query_class=mixed`, 공식/내부 근거 중 하나 이상이면 통과

## 8) 변경 규칙

- 매뉴얼 수정은 **추가(append) 금지**, 항상 교체(update) 방식
- 최신 기준은 이 문서 1개만 유지
