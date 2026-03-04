# AI Canvas 징계 챗봇 구축 가이드 (Step 1 완전판)

> 이 문서 하나만 보고 그대로 따라하면 AI Canvas에서 징계 검토 챗봇을 완성할 수 있습니다.
> 코드·URL·프롬프트 전부 이 문서에 있습니다. 복사-붙여넣기만 하세요.

---

## 1. 전체 구조 한눈에 보기

```
사용자 입력
    ↓
[노드 1] 에이전트  ──→  [노드 2] 에이전트 메시지 가로채기
                                    ↓
                    [노드 3] 에이전트 프롬프트_질의정규화  (AI가 질의를 JSON으로 정규화)
                                    ↓
                    [노드 4] 파이썬_정규화파싱            (JSON 파싱 → 검색어 추출)
                                    ↓
                    [노드 5] 파이썬_URL생성               (API URL 3개 생성)
                         ↓          ↓          ↓
              [노드 6]        [노드 7]       [노드 8]
            API_법령목록    API_판례목록    API_해석목록
                ↓               ↓              ↓
         [노드 9]          [노드 10]       [노드 11]
       파이썬_법령상세URL  파이썬_판례상세URL 파이썬_해석상세URL
                ↓               ↓              ↓
         [노드 12]         [노드 13]       [노드 14]
          API_법령본문      API_판례본문    API_해석본문
                ↓               ↓              ↓
                └───────────────┴──────────────┘
                                ↓
                [노드 15] 데이터 연결_근거통합
                                ↓
                [노드 16] 에이전트 프롬프트_답변생성  (AI가 보고서 작성)
                                ↓
                [노드 17] 파이썬_검열게이트           (근거 2건 미만 → 차단)
                                ↓
                [노드 18] 데이터 조건 분기
                    ↓ (통과)            ↓ (차단)
                    │           [노드 19] 프롬프트_차단응답
                    └──────────────────┘
                                ↓
                [노드 20] 에이전트로 전달
                                ↓
                        사용자에게 응답
```

**핵심 원칙**: 공식 법령 API에서 근거를 2건 이상 수집해야만 답변을 출력합니다. 근거가 부족하면 차단 메시지를 반환합니다.

---

## 2. 시작 전 준비물

| 항목 | 값 | 상태 |
|------|-----|------|
| AI Canvas 계정 | 회사 발급 계정 | 로그인 필요 |
| 법령 API OC 코드 | `tud1211` | 완료 |
| 테스트 질의 | 아래 10개 준비됨 | 완료 |

---

## 3. 새 캔버스 만들기

1. AI Canvas 로그인
2. 워크스페이스 목록에서 **`+ 새 워크스페이스`** 클릭
3. 이름 입력: `징계챗봇-Step1`
4. 빈 캔버스 열림 → 다음 단계 진행

---

## 4. 노드 배치 순서

왼쪽 사이드바에서 노드를 끌어다 캔버스에 놓습니다.
**왼쪽 → 오른쪽** 순서로 배치하면 보기 좋습니다.

| 순서 | 노드 이름 | 카테고리 |
|------|----------|---------|
| 1 | 에이전트 | UI |
| 2 | 에이전트 메시지 가로채기 | 데이터 |
| 3 | 에이전트 프롬프트_질의정규화 | API |
| 4 | 파이썬_정규화파싱 | 전처리 |
| 5 | 파이썬_URL생성 | 전처리 |
| 6 | API_법령목록 | API |
| 7 | API_판례목록 | API |
| 8 | API_해석목록 | API |
| 9 | 파이썬_법령상세URL | 전처리 |
| 10 | 파이썬_판례상세URL | 전처리 |
| 11 | 파이썬_해석상세URL | 전처리 |
| 12 | API_법령본문 | API |
| 13 | API_판례본문 | API |
| 14 | API_해석본문 | API |
| 15 | 데이터 연결_근거통합 | 전처리 |
| 16 | 에이전트 프롬프트_답변생성 | API |
| 17 | 파이썬_검열게이트 | 전처리 |
| 18 | 데이터 조건 분기 | 데이터 |
| 19 | 프롬프트_차단응답 | API |
| 20 | 에이전트로 전달 | 데이터 |

---

## 5. 노드별 상세 설정

> **파이썬 노드 공통 주의사항**
> AI Canvas 파이썬 노드는 `execute()` 함수 내부만 입력 가능합니다.
> 아래 코드를 **그대로 복사해서 `execute()` 안에 붙여넣으세요.**
> `def`, `return`, `yield` 키워드는 AI Canvas에서 에러가 나므로 사용하지 않았습니다.

---

### 노드 1: 에이전트

- **카테고리**: UI > 에이전트
- **설정 항목**:

| 설정 | 값 |
|------|-----|
| 인사말 | `징계 검토 요청을 입력하면 공식 법령/판례 근거 기반으로 답변합니다` |
| 메시지 가로채기 노드 | `에이전트 메시지 가로채기` 선택 |
| 웹 검색 | **끔** |

---

### 노드 2: 에이전트 메시지 가로채기

- **카테고리**: 데이터 > 에이전트 메시지 가로채기
- 별도 설정 없음. 노드 1과 노드 3 사이에 연결만 하면 됩니다.

---

### 노드 3: 에이전트 프롬프트_질의정규화

- **카테고리**: API > 에이전트 프롬프트
- **출력 열 이름**: `normalized_json`
- **툴 사용**: 끔
- **프롬프트** (아래 전체를 복사-붙여넣기):

```
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

---

### 노드 4: 파이썬_정규화파싱

- **카테고리**: 전처리 > 파이썬 스크립트
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

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

---

### 노드 5: 파이썬_URL생성

- **카테고리**: 전처리 > 파이썬 스크립트
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

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

    lq_enc = lq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    pq_enc = pq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    eq_enc = eq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")

    rows.append({
        "law_query_used": lq,
        "prec_query_used": pq,
        "expc_query_used": eq,
        "law_list_url": f"{base}&target=eflaw&search=1&query={lq_enc}&display=5&page=1&sort=ddes",
        "prec_list_url": f"{base}&target=prec&search=1&query={pq_enc}&display=5&page=1&sort=ddes",
        "expc_list_url": f"{base}&target=expc&search=1&query={eq_enc}&display=5&page=1&sort=ddes",
    })

result = pd.DataFrame(rows, columns=[
    "law_query_used",
    "prec_query_used",
    "expc_query_used",
    "law_list_url",
    "prec_list_url",
    "expc_list_url",
])
```

---

### 노드 6: API_법령목록

- **카테고리**: API > 커스텀 API
- **설정**:

| 설정 | 값 |
|------|-----|
| 요청 모드 | 데이터셋 요청 |
| Method | GET |
| URL 컬럼 | `law_list_url` |
| 자동 변환 (JSON → CSV) | **켜짐** |

- **참고 URL 형태** (실제 URL은 노드 5가 자동 생성):
```
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=eflaw&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes
```

---

### 노드 7: API_판례목록

- 노드 6과 동일한 설정
- **URL 컬럼**: `prec_list_url`

- **참고 URL 형태**:
```
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=prec&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes
```

---

### 노드 8: API_해석목록

- 노드 6과 동일한 설정
- **URL 컬럼**: `expc_list_url`

- **참고 URL 형태**:
```
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=expc&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes
```

---

### 노드 9: 파이썬_법령상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 6(API_법령목록) 결과 (ID, MST 컬럼 포함)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    idv = ""
    for k in ["ID", "id", "법령ID", "law_id"]:
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
    for k in ["MST", "mst", "법령일련번호"]:
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

    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    mstv_enc = mstv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")

    if idv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&ID={idv_enc}&type=JSON"
    elif mstv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={mstv_enc}&type=JSON"
    else:
        url = ""

    rows.append({"law_detail_url": url})

result = pd.DataFrame(rows, columns=["law_detail_url"])
```

---

### 노드 10: 파이썬_판례상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 7(API_판례목록) 결과 (ID 컬럼 포함)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    idv = r.get("ID", "")
    if idv is None or (hasattr(pd, "isna") and pd.isna(idv)):
        idv = r.get("id", "")
    if idv is None:
        idv = ""
    else:
        try:
            if pd.isna(idv):
                idv = ""
        except Exception:
            pass
    idv = str(idv).strip()
    if idv.lower() == "nan":
        idv = ""
    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({"prec_detail_url": url})

result = pd.DataFrame(rows, columns=["prec_detail_url"])
```

---

### 노드 11: 파이썬_해석상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 8(API_해석목록) 결과 (ID 컬럼 포함)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    idv = r.get("ID", "")
    if idv is None or (hasattr(pd, "isna") and pd.isna(idv)):
        idv = r.get("id", "")
    if idv is None:
        idv = ""
    else:
        try:
            if pd.isna(idv):
                idv = ""
        except Exception:
            pass
    idv = str(idv).strip()
    if idv.lower() == "nan":
        idv = ""
    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({"expc_detail_url": url})

result = pd.DataFrame(rows, columns=["expc_detail_url"])
```

---

### 노드 12: API_법령본문

- **카테고리**: API > 커스텀 API
- **설정** (노드 6과 동일):

| 설정 | 값 |
|------|-----|
| 요청 모드 | 데이터셋 요청 |
| Method | GET |
| URL 컬럼 | `law_detail_url` |
| 자동 변환 (JSON → CSV) | **켜짐** |

---

### 노드 13: API_판례본문

- 노드 12와 동일한 설정
- **URL 컬럼**: `prec_detail_url`

---

### 노드 14: API_해석본문

- 노드 12와 동일한 설정
- **URL 컬럼**: `expc_detail_url`

---

### 노드 15: 데이터 연결_근거통합

- **카테고리**: 전처리 > 데이터 연결
- **설정**:

| 설정 | 값 |
|------|-----|
| 축 | 수직 |
| 병합 방식 | 공통 열 사용 |
| 입력1 | API_법령본문 결과 |
| 입력2 | API_판례본문 결과 |
| 입력3 | API_해석본문 결과 |

---

### 노드 16: 에이전트 프롬프트_답변생성

- **카테고리**: API > 에이전트 프롬프트
- **출력 열 이름**: `draft_answer`
- **툴 사용**: 끔
- **프롬프트** (아래 전체를 복사-붙여넣기):

```
역할: 근거 기반 징계 검토 보고서 작성
금지: 근거에 없는 단정, 출처 없는 결론
반드시 아래 템플릿을 제목/순서/아이콘/기호까지 그대로 사용
정보가 없으면 빈칸 대신 반드시 `부재`라고 기재
링크는 원문 URL만 허용
법령 1개 + 판례/해석 1개 이상 없으면 `♟️ 종합 판단` 작성 금지
Step1에서는 내부DB를 연결하지 않으므로 `🏢 내부DB 참고`는 기본적으로 `부재`로 기재

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

---

### 노드 17: 파이썬_검열게이트

- **카테고리**: 전처리 > 파이썬 스크립트
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

allow_hosts = (
    "law.go.kr",
    "open.law.go.kr",
    "portal.scourt.go.kr",
    "ecfs.scourt.go.kr",
)
must_slots = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]
url_re = re.compile(r"https?://[^\s)\]]+")

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
                urls = [u.strip() for u in re.split(r"[\s,]+", text) if u.strip().startswith("http")]

    if not urls:
        urls = url_re.findall(draft)

    official_urls = [u for u in urls if any(h in u for h in allow_hosts)]
    evidence = len(official_urls)
    raw_evidence = row.get("official_evidence_count", None)
    if raw_evidence is not None:
        try:
            evidence = int(raw_evidence)
        except Exception:
            evidence = len(official_urls)

    bad_domain = any(not any(h in u for h in allow_hosts) for u in urls) if urls else False
    missing = [s for s in must_slots if s not in draft]
    is_pass = (evidence >= 2) and (not bad_domain) and (len(missing) == 0)

    reasons = []
    if evidence < 2:
        reasons.append("official_evidence_count<2")
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

---

### 노드 18: 데이터 조건 분기

- **카테고리**: 데이터 > 데이터 조건 분기
- **설정**:

| 설정 | 값 |
|------|-----|
| 조건 컬럼 | `is_pass` |
| 조건 | `== true` |
| 참(True) 출력 | → 노드 20 (에이전트로 전달) |
| 거짓(False) 출력 | → 노드 19 (프롬프트_차단응답) |

---

### 노드 19: 프롬프트_차단응답

- **카테고리**: API > 에이전트 프롬프트 (또는 프롬프트)
- **프롬프트** (아래 전체를 복사-붙여넣기):

```
다음 3줄을 반드시 포함해 한국어로 짧게 답변하세요.
1) 현재 공식근거가 부족하여 결론을 제시하지 않습니다
2) 추가 사실/기간/키워드가 필요합니다
3) 불확실/부재 항목: {fail_reason}
```

---

### 노드 20: 에이전트로 전달

- **카테고리**: 데이터 > 에이전트로 전달
- 별도 설정 없음
- 참 분기(통과): `draft_answer` 컬럼을 응답으로 전달
- 거짓 분기(차단): 프롬프트_차단응답 출력을 응답으로 전달

---

## 6. 포트 연결 맵 (엣지 연결 순서)

노드의 오른쪽 동그라미(출력)를 잡아 다음 노드의 왼쪽 동그라미(입력)에 연결합니다.

| From 노드 | From 포트 | To 노드 | To 포트 |
|-----------|----------|---------|---------|
| 에이전트 | 메시지 출력 | 에이전트 메시지 가로채기 | 메시지 입력 |
| 에이전트 메시지 가로채기 | 가로챈 메시지 | 에이전트 프롬프트_질의정규화 | 프롬프트 입력 |
| 에이전트 프롬프트_질의정규화 | `normalized_json` | 파이썬_정규화파싱 | 입력 데이터셋 |
| 파이썬_정규화파싱 | 출력 데이터셋 | 파이썬_URL생성 | 입력 데이터셋 |
| 파이썬_URL생성 | `law_list_url` | API_법령목록 | URL 컬럼 |
| 파이썬_URL생성 | `prec_list_url` | API_판례목록 | URL 컬럼 |
| 파이썬_URL생성 | `expc_list_url` | API_해석목록 | URL 컬럼 |
| API_법령목록 | 목록 결과 (`ID`, `MST` 포함) | 파이썬_법령상세URL | 입력 데이터셋 |
| API_판례목록 | 목록 결과 (`ID` 포함) | 파이썬_판례상세URL | 입력 데이터셋 |
| API_해석목록 | 목록 결과 (`ID` 포함) | 파이썬_해석상세URL | 입력 데이터셋 |
| 파이썬_법령상세URL | `law_detail_url` | API_법령본문 | URL 컬럼 |
| 파이썬_판례상세URL | `prec_detail_url` | API_판례본문 | URL 컬럼 |
| 파이썬_해석상세URL | `expc_detail_url` | API_해석본문 | URL 컬럼 |
| API_법령본문 | 본문 결과 | 데이터 연결_근거통합 | 입력1 |
| API_판례본문 | 본문 결과 | 데이터 연결_근거통합 | 입력2 |
| API_해석본문 | 본문 결과 | 데이터 연결_근거통합 | 입력3 |
| 데이터 연결_근거통합 | 통합 결과 | 에이전트 프롬프트_답변생성 | 프롬프트 컨텍스트 |
| 에이전트 프롬프트_답변생성 | `draft_answer` | 파이썬_검열게이트 | 입력 데이터셋 |
| 파이썬_검열게이트 | `is_pass`, `fail_reason` 포함 결과 | 데이터 조건 분기 | 조건 입력 |
| 데이터 조건 분기 (참) | `draft_answer` | 에이전트로 전달 | 응답 입력 |
| 데이터 조건 분기 (거짓) | 분기 트리거 | 프롬프트_차단응답 | 프롬프트 입력 |
| 프롬프트_차단응답 | 차단 메시지 | 에이전트로 전달 | 응답 입력 |

---

## 7. API URL 전체 목록 (참고용)

> 실제 URL은 파이썬 노드가 자동 생성합니다. 직접 확인하거나 테스트할 때 참고하세요.

### 법령

```
# 목록 조회 (키워드로 검색)
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=eflaw&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes

# 본문 조회 (ID로)
https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&ID={법령ID}&type=JSON

# 본문 조회 (MST로)
https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={법령일련번호}&type=JSON
```

### 판례

```
# 목록 조회
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=prec&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes

# 본문 조회
https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&ID={판례ID}&type=JSON
```

### 행정해석

```
# 목록 조회
https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=expc&type=JSON&search=1&query=징계&display=5&page=1&sort=ddes

# 본문 조회
https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&ID={해석례ID}&type=JSON
```

---

## 8. 완성 후 테스트

### 테스트 방법

1. 에이전트 노드 더블클릭 → 채팅창 열림
2. 아래 질의를 하나씩 입력

### 테스트 질의 10개

```
테스트 1: 직장 내 괴롭힘 반복 폭언 건 징계 수위 검토해줘
테스트 2: 무단결근 3회, 경고 후 재발한 경우 징계 가능한지
테스트 3: 성희롱 의심인데 증거가 일부만 있어
테스트 4: 매우 특이한 사례인데 판례가 있을까?
테스트 5: 근로기준법 제23조 관련 판례 알려줘
테스트 6: 횡령 관련 징계 수위는 어떻게 되나요
테스트 7: 징계 절차가 어떻게 되나요
테스트 8: 감봉 처분의 법적 근거가 뭔가요
테스트 9: 부당해고 구제 신청 방법
테스트 10: 징계위원회 구성 요건
```

### 확인 항목

| 확인 항목 | 정상 | 비정상 |
|----------|------|--------|
| 답변에 `📚 적용 법령` 섹션 있음 | ✅ | 없으면 프롬프트 재확인 |
| 답변에 `법령명`, `조문`, `시행일` 있음 | ✅ | 없으면 API 연결 확인 |
| 답변에 `🧑‍⚖️ 관련 판례` 섹션 있음 | ✅ | 없으면 API 연결 확인 |
| 링크가 `law.go.kr` 도메인 | ✅ | 다른 도메인이면 차단 필요 |
| 근거 부족 시 차단 메시지 출력 | ✅ | 출력 안 되면 노드 18 조건 확인 |
| 정보 없는 항목이 `부재`로 기재됨 | ✅ | 빈칸이면 프롬프트 재확인 |

### Step 1 완료 기준

| 기준 | 목표 |
|------|------|
| 테스트 10건 중 정상 응답 (통과 또는 적절한 차단) | 10 / 10 |
| 공식근거 슬롯 누락 | 0건 |
| 비허용 도메인 URL | 0건 |
| 차단 규칙 오탐 | 0건 |

---

## 9. 자주 하는 실수 & 해결법

| 실수 | 증상 | 해결법 |
|------|------|--------|
| `OC=tud1211` 빠뜨림 | API 호출 결과가 비어 있음 | 노드 5 코드의 `base` URL 확인 |
| 파이썬 코드를 `execute()` 바깥에 붙여넣음 | 파이썬 노드 에러 | `execute():` 줄 아래 들여쓰기 확인 |
| 파이썬 코드에 `def` / `return` 사용 | 실행 차단 에러 | 이 문서의 코드는 해당 키워드 없음. 복사 시 수정하지 말 것 |
| 커스텀 API에서 JSON→CSV 자동변환 끔 | 데이터가 다음 노드로 안 넘어감 | `자동 변환(JSON→CSV): 켜짐` 확인 |
| 에이전트 메시지 가로채기 미연결 | 워크플로우 실행 안 됨 | 노드 1 설정에서 가로채기 노드 선택 확인 |
| 데이터 조건 분기 조건 오류 | 항상 통과 또는 항상 차단 | `is_pass` 컬럼값이 boolean인지 확인 |
| 포트 타입 불일치 | 엣지 연결 안 됨 | 같은 타입 포트끼리만 연결 가능 |
| URL 컬럼명 오타 | API가 URL을 못 읽음 | `law_list_url`, `prec_list_url`, `expc_list_url` 철자 확인 |

---

## 10. Step 2 예고 (내부 DB 연결)

Step 1이 10건 테스트를 모두 통과한 후 진행합니다.

### 추가할 것
- `★징계DB_AI활용 DB최종 작성중.xlsx` → 데이터 저장소 노드에 업로드
- `데이터 저장소 조회` 노드 추가 → 키워드로 내부 사례 검색
- `데이터 연결_근거통합` 노드에 입력4로 연결
- 노드 16 프롬프트의 `🏢 내부DB 참고` 섹션이 실제 데이터로 채워짐

### 비식별 마스킹 필수 확인 (업로드 전)
- 성명 → `OOO` 또는 `직원A`
- 사번 → 삭제 또는 `EMP-001`
- 연락처, 주민등록번호 → 삭제

---

## 11. 전체 일정

| 단계 | 핵심 작업 | 완료 기준 |
|------|----------|----------|
| **Step 1** | 외부 API 연결 + 기본 플로우 | 테스트 10건 통과 |
| **Step 2** | 내부 DB 연결 | 내부 사례 참조 정상 동작 |
| **Step 3** | 앱 배포 + 권한 설정 | 초대 사용자 접근 확인 |
| **Step 4** | 시범운영 + 튜닝 | 환각 케이스 0건 목표 |
