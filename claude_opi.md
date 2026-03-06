# AI Canvas 징계 챗봇 구축 가이드 (v2)

> Step1 자산을 유지하면서 **운영 품질을 높이는 v2 기준 설계서**입니다.
> 이 문서 하나만 보고 따라하면 AI Canvas에서 징계 검토 챗봇 v2를 완성할 수 있습니다.
> 코드·URL·프롬프트 전부 이 문서에 있습니다. 복사-붙여넣기만 하세요.

---

## 변경 로그

| 버전 | 날짜 | 주요 변경 |
|------|------|----------|
| v2 | 2026-03-05 | 23노드 구조, QTYPE 분기, Evidence 표준화/스코어링, 검열게이트 v2 |
| v2.1 | 2026-03-06 | 노드 3 스키마에 query_class/internal_db_required 통합, AIHub 580 적재 전략, LawBot 구조 차용 포인트, QTYPE↔query_class 매핑 명확화, 검증 체크리스트 및 리스크 섹션 추가 |

---

## 이번 업데이트 (v2.1) — 유지 / 추가 / 보류

| 분류 | 항목 | 출처 | 비고 |
|------|------|------|------|
| **유지** | 23노드 v2 흐름 | claude_opi.md | 핵심 구조 변경 없음 |
| **유지** | Evidence 표준화/스코어링 (노드 17/18) | claude_opi.md | v2 핵심 강점 유지 |
| **유지** | QTYPE 분류 (LEGAL_JUDGMENT / INTERNAL_ONLY / HYBRID) | claude_opi.md | 노드 19/20 게이트 기준 Canonical |
| **유지** | 부분 실패 내성 (partial failure tolerance) | claude_opi.md | 운영 4대 원칙 유지 |
| **유지** | 답변 템플릿 (🧊⚖️📚🧑‍⚖️🏢♟️🚀) | claude_opi.md | 실무 출력 양식 유지 |
| **추가** | query_class 필드 → 노드 3 스키마 통합 | manual.md | QTYPE과 역할 분리: 노드 3=사전 분류, 노드 19/20=게이트 분기 |
| **추가** | AIHub 580 로컬 적재 전략 | AIHub 공식 메타데이터 | 로컬 파일 미확인 — [가정] 표시 |
| **추가** | 판결문 XML/JSON → Evidence 스키마 매핑 | AIHub 580 구조 추정 | [가정] 표시 |
| **추가** | 약관 데이터 활용 위치와 한계 | AIHub 580 메타데이터 | 온라인 API 아님, 오프라인 참조 저장소 |
| **추가** | LawBot 구조 차용 포인트 & 노드 매핑 | LawBot GitHub | 구시대 모델명 직접 권장 제외 |
| **추가** | QTYPE ↔ query_class 매핑표 | claude_opi + manual 통합 | 두 체계 충돌 없음, 역할 분리 명시 |
| **추가** | 적용 후 검증 체크리스트 | 신규 작성 | — |
| **추가** | 리스크 / 보류사항 | 신규 작성 | — |
| **보류** | LawBot BERT 검색 / 코사인 유사도 로컬 RAG | LawBot | Phase 4+ 검토 (현재 법령 API로 충분) |
| **보류** | LawBot 모델 (Legal-Llama-2, KoELECTRA 등) | LawBot | 구시대 모델 — 직접 권장 불가 |
| **보류** | AIHub 580 실시간 추론 API 활용 | AIHub | 로컬 오프라인 저장소로만 취급, 실시간 API 미존재 |
| **보류** | internal_db 정규화 16A/16B 세부 | manual.md | Phase 3 설계에 이미 포함 |

---

## v2 주요 변경 요약

| 항목 | Step1 | v2 |
|---|---|---|
| 차단 조건 | 공식근거 2건 미만 또는 슬롯 누락 | QTYPE별 차단 — LEGAL_JUDGMENT는 항상 통과 |
| 근거 부족 처리 | 차단응답 반환 | **[불확실/부재]** 표기 후 답변 생성 유지 |
| 법률 판단 질문 | 공식근거 없으면 차단 | **LLM 법률 지식으로 항상 답변** |
| 내부DB 전용 질문 | 차단 기준 없음 | 공식근거 0건이면 차단 |
| 노드 수 | 20개 | **23개** (+근거통합2, +근거표준화, +근거스코어링) |
| Python 제약 | `re.compile`, `hasattr` 사용 | **제거** (런타임 오류 방지) |
| 답변생성 모델 | gpt-4o-mini | **gpt-5.2** (또는 gpt-5) |
| 내부DB 연동 | 없음 | Phase 3 설계 포함 (즉시 적용 불필요) |

---

## 1. 전체 구조 한눈에 보기

```
사용자 입력
    ↓
[노드 1] 에이전트  ──→  [노드 2] 에이전트 메시지 가로채기
                                    ↓
                    [노드 3] 에이전트 프롬프트_질의정규화
                                    ↓
                    [노드 4] 파이썬_정규화파싱
                                    ↓
                    [노드 5] 파이썬_URL생성
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
                [노드 15] 데이터 연결_근거통합1  (법령+판례)
                                ↓
                [노드 16] 데이터 연결_근거통합2  (근거통합1+해석)
                                ↓
           ★NEW [노드 17] 파이썬_근거표준화   (Evidence 스키마 변환)
                                ↓
           ★NEW [노드 18] 파이썬_근거스코어링  (신뢰도 점수 부여)
                                ↓
                [노드 19] 에이전트 프롬프트_답변생성  (v2 프롬프트)
                                ↓
                [노드 20] 파이썬_검열게이트  (v2.1: QTYPE 분기)
                                ↓
                [노드 21] 데이터 조건 분기
                    ↓ (통과)            ↓ (차단)
                    │           [노드 22] 프롬프트_차단응답
                    └──────────────────┘
                                ↓
                [노드 23] 에이전트로 전달
                                ↓
                        사용자에게 응답
```

**v2 핵심 원칙**:
- 공식근거 1건 이상이면 답변을 출력합니다.
- 근거가 없는 항목은 `[불확실/부재]`로 명시합니다.
- 공식근거 0건 또는 금지 도메인일 때만 차단합니다.
- 외부 API 일부 실패해도 성공한 근거만으로 답변을 생성합니다.

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
3. 이름 입력: `징계챗봇-v2`
4. 빈 캔버스 열림 → 다음 단계 진행

---

## 4. 노드 배치 순서

| 순서 | 노드 이름 | 카테고리 | v2 변경 |
|------|----------|---------|---------|
| 1 | 에이전트 | UI | - |
| 2 | 에이전트 메시지 가로채기 | 데이터 | - |
| 3 | 에이전트 프롬프트_질의정규화 | API | 모델 변경 |
| 4 | 파이썬_정규화파싱 | 전처리 | - |
| 5 | 파이썬_URL생성 | 전처리 | - |
| 6 | API_법령목록 | API | - |
| 7 | API_판례목록 | API | - |
| 8 | API_해석목록 | API | - |
| 9 | 파이썬_법령상세URL | 전처리 | - |
| 10 | 파이썬_판례상세URL | 전처리 | **hasattr 제거** |
| 11 | 파이썬_해석상세URL | 전처리 | **hasattr 제거** |
| 12 | API_법령본문 | API | - |
| 13 | API_판례본문 | API | - |
| 14 | API_해석본문 | API | - |
| 15 | 데이터 연결_근거통합1 | 전처리 | **입력2개 제한 → 법령+판례** |
| 16 | 데이터 연결_근거통합2 | 전처리 | **★NEW: 근거통합1+해석** |
| 17 | 파이썬_근거표준화 | 전처리 | **★NEW** |
| 18 | 파이썬_근거스코어링 | 전처리 | **★NEW** |
| 19 | 에이전트 프롬프트_답변생성 | API | **프롬프트 v2, 모델 변경** |
| 20 | 파이썬_검열게이트 | 전처리 | **v2 로직, re.compile 제거** |
| 21 | 데이터 조건 분기 | 데이터 | - |
| 22 | 프롬프트_차단응답 | API | - |
| 23 | 에이전트로 전달 | 데이터 | - |

---

## 5. 노드별 상세 설정

> **파이썬 노드 공통 주의사항**
> AI Canvas 파이썬 노드는 `execute()` 함수 내부만 입력 가능합니다.
> 아래 코드를 **그대로 복사해서 `execute()` 안에 붙여넣으세요.**
>
> 사용 금지 (런타임 오류 발생):
> - `import ...`
> - `return`, `yield`
> - `re.compile(...)`
> - `hasattr`, `chr`, `format()` 등 일부 built-in
>
> 사전 제공: `pd`, `json`, `re`
> 결과 지정: `result = pd.DataFrame(...)`

---

### 노드 1: 에이전트

- **카테고리**: UI > 에이전트

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
- **권장 모델**: `gpt-5-mini`, max tokens `700`
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
  "must_have": ["법령명","조문","시행일","법원","선고일","사건번호"],
  "query_class": "legal_analysis | internal_db_only | mixed",
  "internal_db_required": false
}
규칙:
- 사용자 입력 의미를 바꾸지 말 것
- `issue_keywords`는 빈 값 금지(최소 1개)
- `law_query`, `precedent_query`, `interpretation_query` 중 최소 1개는 채울 것
- 정보가 부족하면 기본값 `징계` 사용
- 키워드는 3~7개 권장(최소 1개)
- `query_class`: 내부 통계/DB 없이는 답 불가이면 `internal_db_only`, 일반 법률 판단/요건이면 `legal_analysis`, 내부 사실 + 법률 검토 동시 필요이면 `mixed`
- `internal_db_required`: `internal_db_only` 또는 `mixed`이면 `true`, 그 외 `false`
- ※ query_class(노드 3 사전 분류)는 노드 19/20의 QTYPE 게이트와 역할이 다름 — 섹션 19 매핑표 참조

사용자 입력:
{{content}}
```

> **⚠️ 핵심**: 프롬프트 마지막 줄 `{{content}}`가 반드시 있어야 합니다. AI Canvas 에이전트 프롬프트 노드는 입력 데이터셋의 컬럼값을 `{{컬럼명}}` 자리표시자로만 주입합니다. 이 줄이 없으면 가로채기 노드에서 넘어온 사용자 질문이 모델에 전달되지 않습니다.

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
- **v2.3 변경**: `return`/`chr` 완전 제거 — 헬퍼 함수 없이 전체 인라인화 (E-015 대응)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

# 퍼센트 인코딩 조회 테이블 (return/chr/format 미사용 — 헬퍼 함수 없음)
_hex = "0123456789ABCDEF"
_safe_set = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_pct_map = {}
for _i in range(256):
    _bc = bytes([_i]).decode("latin-1")
    if _i < 128 and _bc in _safe_set:
        _pct_map[_i] = _bc
    else:
        _pct_map[_i] = "%" + _hex[_i >> 4] + _hex[_i & 0xF]

_stopwords = {
    "관련", "법령", "판례", "해석", "행정해석", "문의", "질의", "검토",
    "사례", "안내", "부탁", "알려줘", "알려주세요", "무엇인가요", "어떻게",
    "있나요", "되나요", "하나요", "인가요", "인지요", "이란", "이란게",
}

base = "https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON"

rows = []
for _, r in df.iterrows():
    fallback = str(r.get("issue_keywords_csv", "") or "").strip()
    if not fallback or fallback.lower() == "nan":
        fallback = "징계"

    # stopwords 필터 — 인라인 (함수 정의/return 없음)
    _fb_tok = [t.strip() for t in fallback.split(",") if t.strip()]
    _fb_fil = [t for t in _fb_tok if t not in _stopwords and len(t) >= 2]
    fallback_clean = " ".join(_fb_fil[:2]).strip() if _fb_fil else "징계"

    lq = str(r.get("law_query", "") or "").strip()
    if not lq or lq.lower() == "nan":
        lq = fallback_clean
    pq = str(r.get("precedent_query", "") or "").strip()
    if not pq or pq.lower() == "nan":
        pq = fallback_clean
    eq = str(r.get("interpretation_query", "") or "").strip()
    if not eq or eq.lower() == "nan":
        eq = fallback_clean

    # 쿼리별 stopwords 필터 — 인라인
    _lq_tok = [t.strip() for t in lq.split(",") if t.strip()]
    _lq_fil = [t for t in _lq_tok if t not in _stopwords and len(t) >= 2]
    lq_clean = " ".join(_lq_fil).strip() if _lq_fil else lq

    _pq_tok = [t.strip() for t in pq.split(",") if t.strip()]
    _pq_fil = [t for t in _pq_tok if t not in _stopwords and len(t) >= 2]
    pq_clean = " ".join(_pq_fil).strip() if _pq_fil else pq

    _eq_tok = [t.strip() for t in eq.split(",") if t.strip()]
    _eq_fil = [t for t in _eq_tok if t not in _stopwords and len(t) >= 2]
    eq_clean = " ".join(_eq_fil).strip() if _eq_fil else eq

    # 퍼센트 인코딩 — 인라인 리스트 컴프리헨션 (return/chr 없음)
    lq_enc = "".join([_pct_map[b] for b in lq_clean.encode("utf-8")])
    pq_enc = "".join([_pct_map[b] for b in pq_clean.encode("utf-8")])
    eq_enc = "".join([_pct_map[b] for b in eq_clean.encode("utf-8")])

    rows.append({
        "law_query_used": lq_clean,
        "prec_query_used": pq_clean,
        "expc_query_used": eq_clean,
        "law_list_url": f"{base}&target=eflaw&search=1&query={lq_enc}&display=5&page=1&sort=ddes",
        "prec_list_url": f"{base}&target=prec&search=1&query={pq_enc}&display=5&page=1&sort=ddes",
        "expc_list_url": f"{base}&target=expc&search=1&query={eq_enc}&display=5&page=1&sort=ddes",
        "api_method": "GET",
        "api_headers_json": "{}",
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

---

### 노드 6: API_법령목록

- **카테고리**: API > 커스텀 API

| 설정 | 값 |
|------|-----|
| 요청 모드 | 데이터셋 요청 |
| Method 컬럼 | `api_method` |
| URL 컬럼 | `law_list_url` |
| Header 컬럼 | `api_headers_json` |
| Body 컬럼 | `api_body` |
| 자동 변환 (JSON → CSV) | **켜짐** |

> **E-007 방지**: **Method/Header/Body 컬럼을 모두 매핑**해야 `sequence item 0: expected str instance, NoneType found` 오류를 막을 수 있음. URL 컬럼만 설정하고 나머지를 비워두면 오류 발생.

---

### 노드 7: API_판례목록

- 노드 6과 동일한 설정
- **Method 컬럼**: `api_method`
- **URL 컬럼**: `prec_list_url`
- **Header 컬럼**: `api_headers_json`
- **Body 컬럼**: `api_body`

---

### 노드 8: API_해석목록

- 노드 6과 동일한 설정
- **Method 컬럼**: `api_method`
- **URL 컬럼**: `expc_list_url`
- **Header 컬럼**: `api_headers_json`
- **Body 컬럼**: `api_body`

---

### 노드 9: 파이썬_법령상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 6(API_법령목록) 결과
- **v2.3 변경**: `return`/`chr`/`def` 완전 제거 — 인라인화 (E-015 대응)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

# 퍼센트 인코딩 테이블 (return/chr/def 없음)
_hex = "0123456789ABCDEF"
_safe_set = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_pct_map = {}
for _i in range(256):
    _bc = bytes([_i]).decode("latin-1")
    if _i < 128 and _bc in _safe_set:
        _pct_map[_i] = _bc
    else:
        _pct_map[_i] = "%" + _hex[_i >> 4] + _hex[_i & 0xF]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()

    # 인라인 _clean 헬퍼 (함수/return 없음)
    def _cln(v):
        _s = "" if v is None else str(v).strip()
        if not _s or _s.lower() == "nan":
            _s = ""
        if _s.endswith(".0") and _s[:-2].isdigit():
            _s = _s[:-2]
        # 결과를 리스트에 저장 (return 대체)
        _cln_out[0] = _s

    _cln_out = [""]

    # 1) ID 탐색
    idv = ""
    for k in ["ID", "id", "법령ID", "law_id"]:
        if k in row:
            _cln(row[k]); idv = _cln_out[0]
            if idv:
                break

    # 2) MST 탐색
    mstv = ""
    for k in ["MST", "mst", "법령MST", "법령일련번호"]:
        if k in row:
            _cln(row[k]); mstv = _cln_out[0]
            if mstv:
                break

    # 3) efYd 탐색
    efyd = ""
    for k in ["efYd", "efyd", "시행일자", "법령시행일"]:
        if k in row:
            _cln(row[k]); efyd = _cln_out[0]
            if efyd:
                break

    # 4) blob 파싱 (LawSearch:law)
    if not idv and not mstv:
        for k in ["LawSearch:law", "law", "blob", "data"]:
            bv = row.get(k, None)
            if bv is None:
                continue
            try:
                if pd.isna(bv):
                    continue
            except Exception:
                pass
            sv = str(bv).strip()
            if not sv or sv.lower() == "nan":
                continue
            try:
                blob = json.loads(sv)
                if isinstance(blob, list) and blob:
                    blob = blob[0]
                if isinstance(blob, dict):
                    _cln(blob.get("법령ID", blob.get("ID", blob.get("id", "")))); idv = _cln_out[0]
                    _cln(blob.get("법령일련번호", blob.get("MST", blob.get("mst", "")))); mstv = _cln_out[0]
                    _cln(blob.get("법령시행일자", blob.get("efYd", efyd))); efyd = _cln_out[0]
            except Exception:
                pass
            if idv or mstv:
                break

    # 5) 상세링크 역추출
    if not idv and not mstv:
        for k in ["법령상세링크", "detail_link", "링크", "법령URL", "url", "URL"]:
            lv = row.get(k, None)
            if lv is None:
                continue
            lv = str(lv).strip()
            if not lv or lv.lower() == "nan" or not lv.startswith("http"):
                continue
            _m = re.search(r"[&?]ID=([^&\s]+)", lv)
            if _m:
                idv = _m.group(1).strip()
                break
            _m = re.search(r"[&?]MST=([^&\s]+)", lv)
            if _m:
                mstv = _m.group(1).strip()
                break

    # URL 생성 (인라인 인코딩)
    efyd_enc = "".join([_pct_map[b] for b in efyd.encode("utf-8")]) if efyd else ""
    if idv:
        idv_enc = "".join([_pct_map[b] for b in idv.encode("utf-8")])
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&ID={idv_enc}&type=JSON"
        if efyd_enc:
            url += f"&efYd={efyd_enc}"
    elif mstv:
        mstv_enc = "".join([_pct_map[b] for b in mstv.encode("utf-8")])
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={mstv_enc}&type=JSON"
        if efyd_enc:
            url += f"&efYd={efyd_enc}"
    else:
        url = ""

    rows.append({
        "law_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["law_detail_url", "api_method", "api_headers_json", "api_body"])
```

---

### 노드 10: 파이썬_판례상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 7(API_판례목록) 결과
- **v2.3 변경**: `return`/`chr`/`def` 완전 제거 — 인라인화 (E-015 대응)
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

_hex = "0123456789ABCDEF"
_safe_set = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_pct_map = {}
for _i in range(256):
    _bc = bytes([_i]).decode("latin-1")
    if _i < 128 and _bc in _safe_set:
        _pct_map[_i] = _bc
    else:
        _pct_map[_i] = "%" + _hex[_i >> 4] + _hex[_i & 0xF]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()

    # 1) 직접 ID 탐색 (인라인 clean)
    idv = ""
    for k in ["ID", "id", "판례정보일련번호", "판례일련번호", "prec_id"]:
        if k in row:
            _cv = row[k]
            _cv = "" if _cv is None else str(_cv).strip()
            if _cv.lower() == "nan": _cv = ""
            if _cv.endswith(".0") and _cv[:-2].isdigit(): _cv = _cv[:-2]
            if _cv:
                idv = _cv
                break

    # 2) blob 파싱 (PrecSearch:prec)
    if not idv:
        for k in ["PrecSearch:prec", "prec", "blob", "data"]:
            bv = row.get(k, None)
            if bv is None:
                continue
            try:
                if pd.isna(bv):
                    continue
            except Exception:
                pass
            sv = str(bv).strip()
            if not sv or sv.lower() == "nan":
                continue
            try:
                blob = json.loads(sv)
                if isinstance(blob, list) and blob:
                    blob = blob[0]
                if isinstance(blob, dict):
                    _raw = blob.get("판례정보일련번호", blob.get("ID", blob.get("id", "")))
                    _cv = "" if _raw is None else str(_raw).strip()
                    if _cv.lower() == "nan": _cv = ""
                    if _cv.endswith(".0") and _cv[:-2].isdigit(): _cv = _cv[:-2]
                    idv = _cv
            except Exception:
                pass
            if idv:
                break

    # 3) 상세링크 역추출
    if not idv:
        for k in ["판례상세링크", "detail_link", "링크", "판례URL", "url", "URL"]:
            lv = row.get(k, None)
            if lv is None:
                continue
            lv = str(lv).strip()
            if not lv or lv.lower() == "nan" or not lv.startswith("http"):
                continue
            _m = re.search(r"[&?]ID=([^&\s]+)", lv)
            if _m:
                _cv = _m.group(1).strip()
                if _cv.endswith(".0") and _cv[:-2].isdigit(): _cv = _cv[:-2]
                idv = _cv
                break

    if idv:
        idv_enc = "".join([_pct_map[b] for b in idv.encode("utf-8")])
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&ID={idv_enc}&type=JSON"
    else:
        url = ""

    rows.append({
        "prec_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["prec_detail_url", "api_method", "api_headers_json", "api_body"])
```

---

### 노드 11: 파이썬_해석상세URL

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 8(API_해석목록) 결과
- **v2 변경**: `hasattr` 제거 (E-005 오류 방지)
- **v2.2 변경**: blob 파싱 추가(Expc:expc), .0 접미사 제거, 상세링크 역추출, api_* 컬럼 추가
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
# v2.3: def/_pct/_clean_id 제거 (E-015: return/yield 차단 우회)
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

_hex = "0123456789ABCDEF"
_safe_set = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

_pct_map = {}
for _i in range(256):
    _bc = bytes([_i]).decode("latin-1")
    if _i < 128 and _bc in _safe_set:
        _pct_map[_i] = _bc
    else:
        _pct_map[_i] = "%" + _hex[_i >> 4] + _hex[_i & 0xF]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()

    # 1) 직접 ID 탐색 (인라인 clean)
    idv = ""
    for k in ["ID", "id", "행정해석ID", "법령해석례일련번호", "expc_id"]:
        if k in row:
            _cv = row[k]
            _cv = "" if _cv is None else str(_cv).strip()
            try:
                if pd.isna(_cv): _cv = ""
            except Exception:
                pass
            if _cv.lower() == "nan": _cv = ""
            if _cv.endswith(".0") and _cv[:-2].isdigit(): _cv = _cv[:-2]
            if _cv:
                idv = _cv
                break

    # 2) blob 파싱 (Expc:expc 구조)
    if not idv:
        for k in ["Expc:expc", "expc", "blob", "data"]:
            bv = row.get(k, None)
            if bv is None:
                continue
            try:
                if pd.isna(bv):
                    continue
            except Exception:
                pass
            sv = str(bv).strip()
            if not sv or sv.lower() == "nan":
                continue
            try:
                blob = json.loads(sv)
                if isinstance(blob, list) and blob:
                    blob = blob[0]
                if isinstance(blob, dict):
                    _bv = blob.get("법령해석례일련번호", blob.get("ID", blob.get("id", "")))
                    _bv = "" if _bv is None else str(_bv).strip()
                    if _bv.lower() == "nan": _bv = ""
                    if _bv.endswith(".0") and _bv[:-2].isdigit(): _bv = _bv[:-2]
                    idv = _bv
            except Exception:
                pass
            if idv:
                break

    # 3) 상세링크에서 ID 역추출
    if not idv:
        for k in ["해석상세링크", "detail_link", "링크", "해석URL", "url", "URL"]:
            lv = row.get(k, None)
            if lv is None:
                continue
            lv = str(lv).strip()
            if not lv or lv.lower() == "nan" or not lv.startswith("http"):
                continue
            m = re.search(r"[&?]ID=([^&\s]+)", lv)
            if m:
                idv = m.group(1).strip()
                if idv.endswith(".0") and idv[:-2].isdigit():
                    idv = idv[:-2]
                break

    idv_enc = "".join([_pct_map[b] for b in idv.encode("utf-8")]) if idv else ""
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&ID={idv_enc}&type=JSON" if idv else ""

    rows.append({
        "expc_detail_url": url,
        "api_method": "GET",
        "api_headers_json": "{}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=["expc_detail_url", "api_method", "api_headers_json", "api_body"])
```

---

### 노드 12: API_법령본문

- **카테고리**: API > 커스텀 API

| 설정 | 값 |
|------|-----|
| 요청 모드 | 데이터셋 요청 |
| Method 컬럼 | `api_method` |
| URL 컬럼 | `law_detail_url` |
| Header 컬럼 | `api_headers_json` |
| Body 컬럼 | `api_body` |
| 자동 변환 (JSON → CSV) | **켜짐** |

> **E-007 방지**: **Method/Header/Body 컬럼을 모두 매핑**해야 `sequence item 0: expected str instance, NoneType found` 오류를 막을 수 있음. URL 컬럼만 설정하고 나머지를 비워두면 오류 발생.

---

### 노드 13: API_판례본문

- 노드 12와 동일한 설정
- **Method 컬럼**: `api_method`
- **URL 컬럼**: `prec_detail_url`
- **Header 컬럼**: `api_headers_json`
- **Body 컬럼**: `api_body`

---

### 노드 14: API_해석본문

- 노드 12와 동일한 설정
- **Method 컬럼**: `api_method`
- **URL 컬럼**: `expc_detail_url`
- **Header 컬럼**: `api_headers_json`
- **Body 컬럼**: `api_body`

---

### 노드 15: 데이터 연결_근거통합1

- **카테고리**: 전처리 > 데이터 연결

> 데이터 연결 노드는 입력 포트가 **2개만** 지원됩니다. 3개 소스를 연결하려면 두 노드로 나눕니다.

| 설정 | 값 |
|------|-----|
| 축 | **수직** |
| 병합 방식 | **공통 열 사용** |
| 대상 열 선택 | 없음 (수직 연결 시 불필요) |
| 첫 번째 입력 | API_법령본문 결과 |
| 두 번째 입력 | API_판례본문 결과 |

---

### 노드 16: 데이터 연결_근거통합2

- **카테고리**: 전처리 > 데이터 연결

| 설정 | 값 |
|------|-----|
| 축 | **수직** |
| 병합 방식 | **공통 열 사용** |
| 대상 열 선택 | 없음 (수직 연결 시 불필요) |
| 첫 번째 입력 | 노드 15(근거통합1) 결과 |
| 두 번째 입력 | API_해석본문 결과 |

> **Phase 3 (내부DB 연동 시)**: 근거통합2 다음에 노드 추가하거나, 근거통합3 노드를 별도로 만들어 `데이터셋_내부징계DB` 결과를 연결합니다.

---

### 노드 17: 파이썬_근거표준화 ★NEW

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 16(데이터 연결_근거통합2) 결과
- **역할**: 법령/판례/해석/내부DB를 통일된 Evidence 스키마로 변환
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

col_names = [str(c).lower() for c in df.columns.tolist()]
col_str = " ".join(col_names)

# 데이터셋 전체 열 구조로 source_type 판별
if any(k in col_str for k in ["법령명", "mst", "eflaw"]):
    default_source = "law"
elif any(k in col_str for k in ["사건번호", "선고", "prec"]):
    default_source = "precedent"
elif any(k in col_str for k in ["해석례", "expc", "발령"]):
    default_source = "interpretation"
elif any(k in col_str for k in ["violation_type", "case_id", "discipline_level"]):
    default_source = "internal_case"
else:
    default_source = "unknown"

rows = []
ev_idx = 0
for _, r in df.iterrows():
    row = r.to_dict()

    # 행별 source_type 재판별 (URL 기반)
    source_type = default_source
    for k in ["law_detail_url", "prec_detail_url", "expc_detail_url"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if not sv or sv.lower() == "nan":
            continue
        if "eflaw" in sv:
            source_type = "law"
            break
        elif "prec" in sv:
            source_type = "precedent"
            break
        elif "expc" in sv:
            source_type = "interpretation"
            break

    if row.get("violation_type") or row.get("case_id"):
        source_type = "internal_case"

    is_official = source_type in ("law", "precedent", "interpretation")

    # title 추출
    title = ""
    for k in ["법령명", "판례명", "사건명", "해석례명", "사례명", "title", "Title"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if sv and sv.lower() != "nan":
            title = sv
            break

    # authority 추출
    authority = ""
    for k in ["법원", "발령기관", "소관부처", "authority", "기관"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if sv and sv.lower() != "nan":
            authority = sv
            break

    # date 추출
    date_val = ""
    for k in ["선고일", "시행일", "의결일", "발령일", "결정일", "date", "Date"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if sv and sv.lower() != "nan":
            date_val = sv
            break

    # key_point 추출
    key_point = ""
    for k in ["판시요지", "판결요지", "해석요지", "주요내용", "요약", "key_point", "summary", "내용"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if sv and sv.lower() != "nan":
            key_point = sv[:500]
            break

    # url 추출
    url_out = ""
    for k in ["law_detail_url", "prec_detail_url", "expc_detail_url", "url", "URL", "원문URL", "링크"]:
        v = row.get(k, "")
        if v is None:
            continue
        try:
            if pd.isna(v):
                continue
        except Exception:
            pass
        sv = str(v).strip()
        if sv and sv.lower() != "nan" and sv.startswith("http"):
            url_out = sv
            break

    rows.append({
        "evidence_id": str(ev_idx),
        "source_type": source_type,
        "title": title if title else "[제목 없음]",
        "authority": authority,
        "date": date_val,
        "key_point": key_point,
        "url": url_out,
        "is_official": is_official,
        "score": 0.0,
    })
    ev_idx += 1

result = pd.DataFrame(rows, columns=[
    "evidence_id", "source_type", "title", "authority",
    "date", "key_point", "url", "is_official", "score",
])
```

---

### 노드 18: 파이썬_근거스코어링 ★NEW

- **카테고리**: 전처리 > 파이썬 스크립트
- **입력**: 노드 17(파이썬_근거표준화) 결과
- **역할**: 신뢰도/최신성 기반으로 score 부여, official_evidence_count 계산
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
official_count = 0

for _, r in df.iterrows():
    row = r.to_dict()

    source_type = str(row.get("source_type", "")).strip()

    is_official_raw = row.get("is_official", False)
    if isinstance(is_official_raw, str):
        is_official = is_official_raw.lower() in ("true", "1", "yes")
    else:
        is_official = bool(is_official_raw)

    # 신뢰도 기본 점수: 법령 > 판례 > 해석 > 내부DB
    if source_type == "law":
        base_score = 1.0
    elif source_type == "precedent":
        base_score = 0.85
    elif source_type == "interpretation":
        base_score = 0.75
    elif source_type == "internal_case":
        base_score = 0.5
    else:
        base_score = 0.3

    # 최신성 가산 (2020년 이후 +0.05)
    date_val = str(row.get("date", "")).strip()
    if date_val and len(date_val) >= 4 and date_val[:4].isdigit():
        year = int(date_val[:4])
        if year >= 2020:
            base_score = min(1.0, base_score + 0.05)

    # URL 있으면 가산
    url_val = str(row.get("url", "")).strip()
    if url_val and url_val.startswith("http"):
        base_score = min(1.0, base_score + 0.03)

    row["score"] = round(base_score, 2)
    row["is_official"] = is_official

    if is_official:
        official_count += 1

    rows.append(row)

result_df = pd.DataFrame(rows)

# official_evidence_count를 모든 행에 추가
if not result_df.empty:
    result_df["official_evidence_count"] = official_count

result = result_df
```

---

### 노드 19: 에이전트 프롬프트_답변생성

- **카테고리**: API > 에이전트 프롬프트
- **출력 열 이름**: `draft_answer`
- **툴 사용**: 끔
- **권장 모델**: `gpt-5.2` (또는 `gpt-5`), max tokens `4500` (복잡한 케이스는 `6000~7000`)
- **v2.1 변경**: QTYPE 분류 추가 — LEGAL_JUDGMENT는 공식 API 실패 시에도 LLM 법률 지식으로 답변
- **프롬프트** (아래 전체를 복사-붙여넣기):

```
역할: 법률 전문 징계 검토 보고서 작성 (v2.1)
반드시 아래 템플릿을 제목/순서/아이콘/기호까지 그대로 사용
근거가 없는 항목은 빈칸 대신 `[불확실/부재]`로 기재하고 이유 명시

=== [1단계] 질문 유형 분류 (첫 줄에 반드시 출력) ===
아래 셋 중 하나를 선택해 답변 맨 첫 줄에 출력:

[QTYPE: LEGAL_JUDGMENT]
 → 법령/판례/법리/노동법 지식으로 판단 가능한 질문
   예) 징계 양정 적정성, 해고 유효성, 절차 위반 여부, 요건 검토, 징계 수위 타당성

[QTYPE: INTERNAL_ONLY]
 → 회사 내부 DB 없이는 답할 수 없는 질문
   예) 사내 징계 건수 통계, 특정 직원 처분 이력, 내부 양정 기준표 조회

[QTYPE: HYBRID]
 → 법적 판단 + 내부 사례 모두 필요한 복합 질문

=== [2단계] 유형별 처리 방침 ===

LEGAL_JUDGMENT인 경우:
- 공식 검색 결과(Evidence)가 있으면 최우선 활용
- 검색 결과가 없거나 부족해도 법률 전문 지식(근로기준법, 노동법, 대법원 판례 원칙, 징계법리)으로 답변 생성 — 절대 포기하지 말 것
- 법률지식 기반으로 작성한 항목에 `[법률지식 기반]` 태그 표시
- `📚 적용 법령`: 알려진 조문·법령명 서술 (URL 없으면 조문번호만 명시, [불확실/부재] 금지)
- `🧑‍⚖️ 관련 판례`: 알려진 판례 원칙·법리 서술 (사건번호 불명 시 "대법원 판례 원칙" 으로 기재)
- `♟️ 종합 판단`: 반드시 작성

INTERNAL_ONLY인 경우:
- 내부 DB 없이 답변 불가 → `♟️ 종합 판단` 작성 금지
- `🏢 내부DB 참고` 섹션에 "[INTERNAL_ONLY] 내부DB 연동 후 답변 가능"을 명시

HYBRID인 경우:
- 법적 판단 부분: LEGAL_JUDGMENT 방침 적용
- 내부 사례 부분: 내부DB 없으면 [불확실/부재] 표기
- 공식근거 1건 이상 있으면 `♟️ 종합 판단` 작성

=== [3단계] 보고서 템플릿 ===

🧊 사실관계 요약
- {사용자 진술 요약}
- {불명확 포인트}

⚖️ 쟁점
- {쟁점1}
- {쟁점2}

📚 적용 법령
- 법령명: {name — 검색 결과 또는 [법률지식 기반] 조문}
- 조문: {article}
- 시행일: {effective_date 또는 [불확실/부재]}
- 해석 포인트: {point}
- 근거 링크: {url — 없으면 생략}

🧑‍⚖️ 관련 판례
- 법원: {court 또는 [법률지식 기반] 원칙}
- 선고일: {date 또는 [불확실/부재]}
- 사건번호: {case_no 또는 [불확실/부재]}
- 판시요지: {holding}
- 근거 링크: {url — 없으면 생략}

🏢 내부DB 참고
- 사내 규정: {rule_name 또는 [불확실/부재]}
- 유사 징계사례: {case_id / 요약 또는 [불확실/부재]}
- 차이점: {difference 또는 [불확실/부재]}

♟️ 종합 판단
- {LEGAL_JUDGMENT·HYBRID는 반드시 작성. INTERNAL_ONLY는 생략}

🚀 다음 액션
- {필요 증거 또는 추가 정보}
- {문서/절차}
- {기한}

[불확실/부재]
- {확인되지 않은 항목 명시}
```

---

### 노드 20: 파이썬_검열게이트

- **카테고리**: 전처리 > 파이썬 스크립트
- **v2.1 변경**:
  - `re.compile()` → `while + re.search()` (E-006 오류 방지)
  - **QTYPE 분류 기반 게이트**: LEGAL_JUDGMENT는 공식근거 0건이어도 통과
  - INTERNAL_ONLY는 공식근거 0건이면 차단
  - 금지 도메인은 QTYPE 무관하게 항상 차단
- 아래 코드를 `execute()` 내부에 복사-붙여넣기:

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

allow_hosts = (
    "law.go.kr",
    "open.law.go.kr",
    "portal.scourt.go.kr",
    "ecfs.scourt.go.kr",
)

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

    # QTYPE 추출 (노드 18이 첫 줄에 출력한 마커)
    qtype = "HYBRID"
    m_q = re.search(r"\[QTYPE:\s*(LEGAL_JUDGMENT|INTERNAL_ONLY|HYBRID)\]", draft)
    if m_q:
        qtype = m_q.group(1).strip()

    # URL 추출: re.compile 금지 → while + re.search 반복
    urls = []
    search_text = draft
    while True:
        m = re.search(r"https?://[^\s)\]]+", search_text)
        if not m:
            break
        urls.append(m.group(0))
        search_text = search_text[m.end():]

    official_urls = [u for u in urls if any(h in u for h in allow_hosts)]
    evidence = len(official_urls)

    # 노드 17에서 넘어온 official_evidence_count 우선 사용
    raw_evidence = row.get("official_evidence_count", None)
    if raw_evidence is not None:
        try:
            evidence = int(raw_evidence)
        except Exception:
            pass

    bad_domain = any(not any(h in u for h in allow_hosts) for u in urls) if urls else False

    # v2.1 QTYPE 기반 게이트 정책
    reasons = []
    if bad_domain:
        is_pass = False
        reasons.append("domain_not_allowed")
    elif qtype == "LEGAL_JUDGMENT":
        # 법률 판단 질문: LLM 법률 지식으로 항상 답변 가능 → 항상 통과
        is_pass = True
    elif qtype == "INTERNAL_ONLY":
        # 내부DB 전용 질문: 공식근거 없으면 차단
        is_pass = (evidence >= 1)
        if evidence == 0:
            reasons.append("internal_only_no_evidence")
    else:
        # HYBRID 또는 미분류: 공식근거 1건 이상 필요
        is_pass = (evidence >= 1)
        if evidence == 0:
            reasons.append("official_evidence_count=0")

    row["is_pass"] = bool(is_pass)
    row["question_type"] = qtype
    row["official_evidence_count"] = int(evidence)
    row["fail_reason"] = " / ".join(reasons) if reasons else ""
    rows.append(row)

result = pd.DataFrame(rows)
```

---

### 노드 21: 데이터 조건 분기

- **카테고리**: 데이터 > 데이터 조건 분기

| 설정 | 값 |
|------|-----|
| 조건 컬럼 | `is_pass` |
| 조건 | `== true` |
| 참(True) 출력 | → 노드 22 (에이전트로 전달) |
| 거짓(False) 출력 | → 노드 21 (프롬프트_차단응답) |

---

### 노드 22: 프롬프트_차단응답

- **카테고리**: API > 에이전트 프롬프트 (또는 프롬프트)
- **권장 모델**: `gpt-5-nano`, max tokens `250`
- **프롬프트** (아래 전체를 복사-붙여넣기):

```
다음 3줄을 반드시 포함해 한국어로 짧게 답변하세요.
1) 공식근거를 찾을 수 없어 결론을 제시하지 않습니다
2) 추가 사실/기간/키워드를 제공하면 재검색하겠습니다
3) 차단 사유: {fail_reason}
```

---

### 노드 23: 에이전트로 전달

- **카테고리**: 데이터 > 에이전트로 전달
- 별도 설정 없음
- 참 분기(통과): `draft_answer` 컬럼을 응답으로 전달
- 거짓 분기(차단): 프롬프트_차단응답 출력을 응답으로 전달
- **주의**: 전달 컬럼은 반드시 `output_response` 또는 `output_response_1` 선택 (`question_*` 컬럼 선택 금지)

---

## 6. 포트 연결 맵 (v2)

| From 노드 | From 포트 | To 노드 | To 포트 |
|-----------|----------|---------|---------|
| 에이전트 | 메시지 출력 | 에이전트 메시지 가로채기 | 메시지 입력 |
| 에이전트 메시지 가로채기 | 가로챈 메시지 | 에이전트 프롬프트_질의정규화 | 프롬프트 입력 |
| 에이전트 프롬프트_질의정규화 | `normalized_json` | 파이썬_정규화파싱 | 입력 데이터셋 |
| 파이썬_정규화파싱 | 출력 데이터셋 | 파이썬_URL생성 | 입력 데이터셋 |
| 파이썬_URL생성 | `law_list_url` | API_법령목록 | URL 컬럼 |
| 파이썬_URL생성 | `prec_list_url` | API_판례목록 | URL 컬럼 |
| 파이썬_URL생성 | `expc_list_url` | API_해석목록 | URL 컬럼 |
| API_법령목록 | 목록 결과 | 파이썬_법령상세URL | 입력 데이터셋 |
| API_판례목록 | 목록 결과 | 파이썬_판례상세URL | 입력 데이터셋 |
| API_해석목록 | 목록 결과 | 파이썬_해석상세URL | 입력 데이터셋 |
| 파이썬_법령상세URL | `law_detail_url` | API_법령본문 | URL 컬럼 |
| 파이썬_판례상세URL | `prec_detail_url` | API_판례본문 | URL 컬럼 |
| 파이썬_해석상세URL | `expc_detail_url` | API_해석본문 | URL 컬럼 |
| API_법령본문 | 본문 결과 | 데이터 연결_근거통합1 | 첫 번째 입력 |
| API_판례본문 | 본문 결과 | 데이터 연결_근거통합1 | 두 번째 입력 |
| 데이터 연결_근거통합1 | 통합1 결과 | 데이터 연결_근거통합2 | 첫 번째 입력 |
| API_해석본문 | 본문 결과 | 데이터 연결_근거통합2 | 두 번째 입력 |
| 데이터 연결_근거통합2 | 통합2 결과 | 파이썬_근거표준화 | 입력 데이터셋 |
| 파이썬_근거표준화 | Evidence 스키마 결과 | 파이썬_근거스코어링 | 입력 데이터셋 |
| 파이썬_근거스코어링 | 스코어링 결과 | 에이전트 프롬프트_답변생성 | 프롬프트 컨텍스트 |
| 에이전트 프롬프트_답변생성 | `draft_answer` | 파이썬_검열게이트 | 입력 데이터셋 |
| 파이썬_검열게이트 | `is_pass`, `fail_reason` 포함 결과 | 데이터 조건 분기 | 조건 입력 |
| 데이터 조건 분기 (참) | `draft_answer` | 에이전트로 전달 | 응답 입력 |
| 데이터 조건 분기 (거짓) | 분기 트리거 | 프롬프트_차단응답 | 프롬프트 입력 |
| 프롬프트_차단응답 | 차단 메시지 | 에이전트로 전달 | 응답 입력 |

---

## 7. API URL 전체 목록 (참고용)

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

### 확인 항목 (v2 기준)

| 확인 항목 | 정상 | 비정상 |
|----------|------|--------|
| 공식근거 1건 이상 시 답변 출력 | ✅ | 없으면 노드 19 조건 확인 |
| 근거 부족 항목이 `[불확실/부재]`로 표기 | ✅ | 빈칸이면 프롬프트 재확인 |
| 공식근거 0건일 때만 차단응답 | ✅ | 과도 차단이면 노드 19 evidence 로직 확인 |
| 링크가 `law.go.kr` 도메인 | ✅ | 다른 도메인이면 bad_domain 차단 |
| `♟️ 종합 판단` 섹션 있음 (근거 있을 때) | ✅ | 없으면 프롬프트 재확인 |
| `[불확실/부재]` 섹션에 누락 항목 명시 | ✅ | 빈칸이면 프롬프트 재확인 |
| Evidence 스키마로 정규화된 데이터 흐름 | ✅ | 노드 16 출력 데이터보기로 확인 |

### v2 완료 기준 (DoD)

| 기준 | 목표 |
|------|------|
| 공식근거 1건 이상 케이스에서 차단 없이 답변 | 10 / 10 |
| 공식근거 0건인 경우에만 차단응답 | 확인 |
| 일부 API 실패 상황에서도 파이프라인 중단 없음 | 확인 |
| `[불확실/부재]` 일관 출력 | 확인 |

---

## 8-1. v2 운영 4대 원칙 (한눈에 보기)

> 운영 중 판단이 흔들릴 때 이 4가지만 확인하세요.

| # | 원칙 | 상세 |
|---|------|------|
| 1 | **성공한 소스만 표준 스키마로 통합** | 법령/판례/해석 중 일부 API가 실패해도 성공한 근거만 Evidence 스키마로 변환해 파이프라인 유지 |
| 2 | **공식근거 1건 이상이면 답변 생성 유지** | `official_evidence_count >= 1`이면 차단하지 않고 답변 생성 경로를 계속 진행 |
| 3 | **내부DB가 비어도 중단 없이 진행** | Phase 3 내부DB 미연동 상태에서도 노드 15~17이 정상 동작해야 함 |
| 4 | **내부DB는 보조 용도만** | 법적 결론의 단독 근거로 사용하지 않음 — 유사사례·양정 비교·사내 절차에만 활용 |

---

## 9. 자주 하는 실수 & 해결법 (v2)

| 실수 | 증상 | 해결법 |
|------|------|--------|
| 노드 10/11에 구버전 코드(hasattr 포함) 사용 | `name 'hasattr' is not defined` | 이 문서의 노드 10/11 코드로 교체 |
| 노드 19에 구버전 코드(re.compile 포함) 사용 | `Not allowed context: compile(` | 이 문서의 노드 19 코드로 교체 |
| 노드 22에서 `question_*` 컬럼 선택 | 응답 컬럼 미노출 | `output_response` 또는 `output_response_1` 선택 |
| 노드 16~17 연결 누락 | 근거표준화/스코어링 건너뜀 | 포트 연결 맵 6절 재확인 |
| `official_evidence_count` 컬럼 없음 | 노드 19에서 evidence 계산 오류 | 노드 17 출력 확인, 컬럼 정상 생성 여부 확인 |
| 목록 API(6~8) 실패 후 전체 재실행 | 연쇄 중단 | 실패 노드만 1~2회 재시도 |
| API URL에 `OC=tud1211` 누락 | API 응답 비어 있음 | 노드 5 코드의 `base` URL 확인 |
| 파이썬 코드에 `return` 또는 `import` 사용 | 실행 차단 에러 | 이 문서의 코드는 해당 키워드 없음 |
| 커스텀 API JSON→CSV 자동변환 끔 | 데이터 다음 노드 미전달 | `자동 변환(JSON→CSV): 켜짐` 확인 |
| 노드 5/9~11에서 query 이중 인코딩 | API URL에 `%25EC...` 포함 | 인코딩 1회만 허용 — 이미 `%`로 시작하면 다시 인코딩 금지 |
| 커스텀 API 노드에서 Method/Header/Body 컬럼 비워둠 | `sequence item 0: expected str instance, NoneType found` | URL 컬럼만 설정하면 안 됨 — **Method 컬럼 → `api_method`, Header 컬럼 → `api_headers_json`, Body 컬럼 → `api_body` 모두 매핑 필수** |

---

## 10. 단계별 전환 계획

| Phase | 작업 | 기간 | 완료 기준 |
|------|------|------|----------|
| **Phase 1** | 게이트 완화 + Python 코드 오류 수정 (노드 10, 11, 19) | 1~2일 | 기존 테스트 10건 재통과 |
| **Phase 2** | 근거표준화(노드 16) + 근거스코어링(노드 17) 도입 | 2~4일 | Evidence 스키마 정상 출력 확인 |
| **Phase 3** | 내부DB 조회 노드 연결 (노드 15 입력4 추가) | 3~5일 | 유사사례 섹션 실데이터 반영 |
| **Phase 4** | 중계 API 도입 + 실패율 모니터링 | 운영 중 | API 실패율 < 5% |

---

## 10-1. Worker 재시도 프록시 (선택 적용)

외부 API 간헐 오류를 자동 재시도로 흡수합니다. 다음 중 1개라도 해당하면 적용을 권장합니다:

1. 같은 URL이 수동 재실행에서만 간헐 성공
2. 하루 3회 이상 `[Errno 104]` 발생
3. 목록 API red가 본문/통합 노드까지 연쇄 차단

### Worker URL 설정 방법

노드 5 URL 생성 코드의 `base` 변수를 Worker URL로 교체합니다:

```python
# Worker 미사용 (기본)
# base = "https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON"

# Worker 사용 시 아래 줄로 교체 (실제 Worker URL 입력)
worker_base = "https://law-retry-proxy.<your-subdomain>.workers.dev"
base = f"{worker_base}/drf/search?oc=tud1211&type=JSON"
```

노드 9~11도 동일하게 `law.go.kr` 대신 Worker URL 경유로 변경합니다.

### Worker 적용 기준 & 중단 기준

| 구분 | 기준 |
|------|------|
| 적용 권장 | `[Errno 104]` 하루 3회 이상 / 간헐 성공 반복 |
| Worker 적용 후 502 반복 | upstream 장애로 판단 → 관리자 문의 |

---

## 11. Phase 3: 내부 징계 DB 연동 (예고)

Phase 2까지 완료 후 진행합니다.

### 추가할 노드

- `데이터셋_내부징계DB`: 징계 이력 엑셀 업로드 (비식별화 필수)
- 또는 `API_내부징계DB조회`: 사내 API 연결

### 연결 방법

- 노드 15(데이터 연결_근거통합)의 **입력4**에 내부DB 결과 연결
- 노드 16(파이썬_근거표준화)이 자동으로 `source_type = "internal_case"` 처리
- 노드 18 프롬프트의 `🏢 내부DB 참고` 섹션이 실데이터로 채워짐

### 내부DB 최소 스키마

| 컬럼 | 설명 |
|---|---|
| `case_id` | 사건 ID |
| `violation_type` | 위반유형 |
| `fact_summary` | 사실 요약 |
| `discipline_level` | 징계수위 |
| `aggravating` | 가중사유 |
| `mitigating` | 감경사유 |
| `rule_ref` | 사내규정 조항 |
| `decision_date` | 의결일 |

### 비식별 마스킹 필수 확인 (업로드 전)

- 성명 → `OOO` 또는 `직원A`
- 사번 → 삭제 또는 `EMP-001`
- 연락처, 주민등록번호 → 삭제

### 운영 원칙

- 내부DB는 법적 결론의 단독 근거로 사용하지 않음
- `유사사례`, `양정 비교`, `사내 절차`에만 사용
- 내부DB가 비어도 워크플로우 중단 없이 진행

---

## 12. 모델 권장값 요약

| 노드 | 권장 모델 | max tokens |
|------|----------|-----------|
| 노드 3 (질의정규화) | `gpt-5-mini` | 700 |
| 노드 18 (답변생성) | `gpt-5.2` 또는 `gpt-5` | 4500 (필요 시 6000~7000) |
| 노드 21 (차단응답) | `gpt-5-nano` | 250 |

> `gpt-4o-mini`를 답변생성에 사용하면 템플릿 누락, 법률 문맥 정밀도 저하, 긴 답변에서 근거 연결 약화 현상이 발생할 수 있습니다.

---

## 13. 오류 이력 & 빠른 대응

| ID | 노드 | 에러 | 원인 | 해결 |
|---|---|---|---|---|
| E-001 | 노드4 | `Not allowed context: import json` | 중간 코드에 import 사용 | import 없는 코드로 교체 |
| E-002 | 노드4 | `Not allowed context: return or yield` | return/yield 사용 | `result = ...` 방식으로 변경 |
| E-003 | 노드5 | `name 'chr' is not defined` | 제한 런타임 built-in 차단 | `chr` 미사용 코드 적용 |
| E-004 | 노드5 | `name 'format' is not defined` | 제한 런타임 built-in 차단 | f-string으로 대체 |
| E-005 | 노드10/11 | `name 'hasattr' is not defined` | 제한 런타임 built-in 차단 | **이 문서 노드 10/11 코드로 교체** |
| E-006 | 노드19 | `Not allowed context: compile(` | `re.compile()` 사용 | **이 문서 노드 19 코드로 교체** |
| E-007 | 노드6~8, 12~14 | `sequence item 0: expected str instance, NoneType found` | Method/Header/Body 컬럼 중 하나라도 비어있거나 None 포함 | **Method 컬럼 → `api_method`, Header 컬럼 → `api_headers_json`, Body 컬럼 → `api_body` 모두 매핑** + 빈 행 제거 |
| E-008 | 노드12~14 | `비정상적인 URL이 포함되어 있습니다` | detail_url 빈값/깨진값 | 노드 9~11 URL 생성 로직 확인 |
| E-009 | 노드9~11 | detail URL 빈값 | API 결과가 blob(`LawSearch:law` 등) 형태 | blob 파싱 버전 코드 적용 / 목록 API 데이터보기로 컬럼 형태 사전 확인 |
| E-010 | 노드6 | `[Errno 104] Connection reset by peer` | 외부 API 일시 연결 리셋 | 실패 노드만 1~2회 재시도 |
| E-011 | 노드22 | 응답 컬럼 미노출 | `question_*` 컬럼 선택 | `output_response*` 선택 |
| E-012 | 노드15 | 목록 API 일부 실패 시 통합 노드 오류 | 상류 red 노드 데이터 끊김 | v2 부분 성공 허용 구조로 해결 |
| E-013 | 노드19 | 과도 차단 | `evidence >= 2` 기준 엄격 | **v2: `evidence >= 1` 기준으로 완화** |
| E-014 | 노드5~11 | API 간헐 실패 / 깨진 URL | query 이중 인코딩 (`%25EC...` 발생) | 인코딩 1회 원칙 준수 — `_pct_map` 테이블로 단일 인코딩만 적용 |
| E-015 | 노드5 | `Not allowed context: return or yield` | `def` 헬퍼 함수 내부의 `return` 포함 — 런타임이 함수 내부 `return`도 차단 | **v2.3 코드로 교체** — `def` 함수 정의 전부 제거, 퍼센트 인코딩은 `_pct_map` 조회 + 인라인 리스트 컴프리헨션으로 대체 |

### 즉시 대응 Runbook

1. 워밍업 호출 1회 실행
2. 목록 API 순차 실행: `6 → 7 → 8`
3. 실패 시 전체 재실행 금지, **실패 노드만 1~2회 재시도**
4. 상세 URL 확인: `law_detail_url`, `prec_detail_url`, `expc_detail_url`
5. 본문 API 실행: `12 → 13 → 14`
6. 최종 전달 컬럼은 `output_response*`만 선택

### 관리자 문의 기준

아래 **모두** 해당할 때만 사이트/네트워크 담당 문의:
1. 동일 URL 단일 호출이 30분 이상 지속 실패
2. 재시도 3회 이상에도 반복 실패
3. `403/429` 또는 연결 실패가 전 노드에서 지속 발생

그 외는 대부분 외부 API 일시 불안정 또는 노드 설정/데이터 품질 문제로 현장 복구 가능합니다.

---

## 14. 테스트 로그 템플릿 (복붙용)

```text
[YYYY-MM-DD HH:mm] 케이스명:
- 입력:
- 실패 노드:
- 에러 메시지:
- 즉시 조치:
- 재실행 결과:
- 재발 방지 반영:
```

---

## 15. AIHub 580 로컬 데이터 적재 전략

> **공식 데이터셋**: AIHub 데이터셋 #580 — 법률/규정(판결서, 약관 등) 텍스트 분석 데이터 (2021년 구축)
>
> **⚠️ 로컬 파일 확인 결과**: 현재 프로젝트 경로(`/home/user/ai-canvas/`) 및 연결된 GitHub 저장소 내에 AIHub 580의 XML/JSON 샘플 파일이 존재하지 않음을 확인했습니다. 아래 내용은 공식 AIHub 메타데이터와 데이터셋 설명서 기준으로 작성했으며, 실제 파일 구조와 다를 수 있습니다. 차이가 발견되면 실제 파일 구조를 우선하고 이 섹션을 수정하세요.

### 15-1. 데이터셋 구성 개요

| 구분 | 내용 | 포맷 | 건수 |
|------|------|------|------|
| 판결문 분석 | 기초사실·주장·판결 주문·이유 구조화 | XML (추정) | 1만+ 건 |
| 약관 분석 | 유·불리 조항 판단, 위법성 태깅 | JSON (추정) | 1만+ 건 |

> 샘플링 기준 연도: 2017, 2020, 2021 (수집 원본 판결문 연도 기준, [가정])

### 15-2. 로컬 적재 원칙

1. **오프라인 증거 저장소로만 취급** — AIHub 580은 실시간 API가 아닙니다. 답변 생성에 직접 연결하지 않습니다.
2. **내부DB 연동 경로로 진입** — Phase 3(섹션 11)의 `데이터셋_내부징계DB` 노드로 적재합니다.
3. **비식별화 필수** — 판결문 내 자연인 식별 정보(성명, 주민등록번호, 연락처) 마스킹 후 사용합니다.
4. **source_type 지정** — 노드 17(파이썬_근거표준화)에서 `source_type = "precedent"` (판결문) 또는 `source_type = "regulation_terms"` (약관)으로 분류됩니다.

### 15-3. 적재 절차 (복붙용 체크리스트)

```text
[ ] 1. AIHub 580 압축 해제 후 판결문/약관 디렉토리 분리
[ ] 2. 판결문 XML: 섹션 16의 매핑 스크립트로 Evidence 스키마 변환
[ ] 3. 약관 JSON: 섹션 17의 활용 가이드에 따라 선택적 변환
[ ] 4. 비식별화 검토 (성명→OOO, 주민번호→삭제, 연락처→삭제)
[ ] 5. AI Canvas 데이터셋 노드로 업로드 (엑셀 또는 CSV 변환 후)
[ ] 6. 노드 15 입력4 또는 근거통합3 노드에 연결
[ ] 7. 노드 17 출력에서 source_type 컬럼 정상 확인
[ ] 8. 섹션 20의 검증 체크리스트 실행
```

---

## 16. 판결문 XML/JSON 라벨 → Evidence 스키마 매핑

> **[가정]**: 로컬 파일 미확인. 아래 매핑은 AIHub 580 공식 설명서 및 유사 데이터셋(전문분야 말뭉치, 법률 AI 판결문) 기준 추정입니다. 실제 파일 열람 후 반드시 검증하고 차이를 기록하세요.

### 16-1. 판결문 XML 공통 필드 (추정)

| XML 태그 / 필드명 | Evidence 스키마 컬럼 | 비고 |
|-------------------|---------------------|------|
| 사건번호 | (title 보조, key_point 내 포함) | 예: `2019가합12345` |
| 선고일 / 판결일자 | `date` | YYYYMMDD 또는 YYYY-MM-DD |
| 법원명 | `authority` | 예: `대법원`, `서울고등법원` |
| 사건명 / 사건유형 | `title` | |
| 주문 | `key_point` 앞부분 | 500자 이내 요약 권장 |
| 이유 (판시요지) | `key_point` | 핵심 법리 500자 이내 요약 |
| 참조조문 | (key_point 내 포함 또는 별도 필드) | |
| 참조판례 | (key_point 내 포함) | |
| 원문URL | `url` | AIHub 580은 오프라인, 빈 문자열 또는 law.go.kr 링크 |

**source_type**: `"precedent"`
**is_official**: `False` (공식 law.go.kr API 경로가 아닌 로컬 파일)
**score 기본값**: `0.70` (판례 기본 0.85에서 로컬 파일 신뢰도 차감 [가정])

### 16-2. 약관 JSON 공통 필드 (추정)

| JSON 키 | Evidence 스키마 컬럼 | 비고 |
|---------|---------------------|------|
| 약관명 | `title` | |
| 조항번호 | `title` 보조 (title에 병합) | 예: `제3조` |
| 조항내용 | `key_point` | 500자 이내 |
| 유불리_판단 | `key_point` 내 태그 | `유리 / 불리 / 중립` |
| 위법성_여부 | `key_point` 내 태그 | |
| 위법_이유 | `key_point` 보조 | |
| 관련_법조문 | `key_point` 내 포함 | |
| 약관발행기관 | `authority` | [가정] 필드명 상이할 수 있음 |

**source_type**: `"regulation_terms"` (노드 17 기본값에 없으므로 수동 지정 필요)
**is_official**: `False`
**score 기본값**: `0.55` [가정]

### 16-3. 로컬 파일 구조가 위 추정과 다를 때

실제 XML/JSON 파일을 열었을 때 위 필드명이 다를 경우:

```text
[ ] 실제 필드명을 위 표에 직접 기입 (수정 후 [가정] 태그 제거)
[ ] 매핑 불가 필드는 key_point에 "원문: {원래값}" 형태로 병합
[ ] source_type 기본값은 노드 17 코드에서 직접 elif 조건 추가
```

---

## 17. 약관 데이터 활용 위치와 활용 한계

### 활용 가능 위치

| 활용 단계 | 구체적 방법 |
|----------|------------|
| Phase 3 내부DB 연동 | `데이터셋_내부징계DB` 노드에 약관 데이터 병합 후 근거통합 경로로 진입 |
| 노드 17 (파이썬_근거표준화) | `source_type = "regulation_terms"` 으로 분류, Evidence 스키마 변환 |
| 노드 19 답변생성 | `🏢 내부DB 참고` 섹션의 `사내 규정` 항목에 약관 조항 활용 |

### 활용 한계 (반드시 숙지)

1. **실시간 API 아님** — AIHub 580 약관 데이터는 로컬 파일이며 실시간 업데이트되지 않습니다.
2. **법적 결론의 단독 근거 불가** — 약관 조항은 `유사사례`, `사내 절차 확인` 용도로만 활용합니다.
3. **is_official = False** — 노드 20 검열게이트에서 `official_evidence_count`에 포함되지 않습니다. 약관만 있을 때 `LEGAL_JUDGMENT` 질문이 아니면 차단될 수 있습니다.
4. **연도 기준 주의** — 2017/2020/2021 샘플은 최신 약관 개정을 반영하지 않을 수 있습니다. 답변에 `[불확실/부재 — AIHub 580 기준, 최신 약관 확인 필요]` 표기를 권장합니다.
5. **약관 유불리 판단은 참고용** — LLM의 법적 판단을 대체하지 않습니다.

---

## 18. LawBot 구조 차용 포인트와 claude_opi 노드 매핑

> **출처**: [LawBot-Online-Legal-Advice-LLM-Service](https://github.com/boostcampaitech5/LawBot-Online-Legal-Advice-LLM-Service)
> **주의**: LawBot에서 사용된 특정 모델(Legal-Llama-2, KoELECTRA 등)은 구시대 모델이므로 직접 권장하지 않습니다. 파이프라인 설계 패턴만 참조합니다.

### 18-1. LawBot 4단계 파이프라인 vs claude_opi 노드 매핑

| LawBot 단계 | LawBot 역할 | claude_opi 대응 노드 | 비고 |
|------------|------------|---------------------|------|
| **Filter** | 법률/비법률 질문 분류 (0.95 임계값) | 노드 3 `query_class` + 노드 20 QTYPE 게이트 | claude_opi에서는 게이트 통과 여부로 동등 구현 |
| **Retrieve** | BERT 기반 유사 QA 검색 | 노드 6~14 (law.go.kr API 검색) | API 기반 검색이 로컬 임베딩 검색 대체 |
| **Generate** | LLM 답변 생성 | 노드 19 (에이전트 프롬프트_답변생성) | 동일 역할 |
| **Search** | 코사인 유사도 판례 상위 3건 | 노드 7/10/13 (API_판례목록/본문) | API 결과가 유사도 검색 대체 |

### 18-2. 차용한 설계 패턴

1. **순차 파이프라인 + 단일 책임 노드**: 각 노드가 단일 역할만 수행 → claude_opi 23노드 구조와 일치
2. **질문 유형 필터링 선행**: 잘못된 질문 유형을 초기에 걸러내는 필터 단계 → 노드 3 query_class + 노드 20 QTYPE 게이트
3. **검색 + 생성 분리**: 근거 검색과 답변 생성을 별도 단계로 분리 → 노드 6~16(검색) vs 노드 19(생성)
4. **출처 URL 명시**: 법령 조문에서 law.go.kr URL 구성 → 노드 9~11 URL 생성 패턴과 일치

### 18-3. 차용하지 않은 항목 (보류 이유)

| LawBot 항목 | 보류 이유 |
|------------|----------|
| 로컬 BERT/임베딩 벡터 DB | 법령 API로 충분, 인프라 비용 과다 (Phase 4+ 검토) |
| 코사인 유사도 0.5 임계값 필터 | API 결과 quality가 더 안정적 |
| 사전학습 한국어 법률 모델 | 구시대 모델 의존성 제거 (GPT-5 계열 사용) |
| Airflow 파이프라인 스케줄링 | AI Canvas 플랫폼 내에서 처리 |

---

## 19. QTYPE ↔ query_class 매핑표

> **핵심**: 두 체계는 충돌하지 않습니다. **역할과 단계가 다릅니다.**

| 단계 | 필드명 | 생성 노드 | 역할 | 사용 위치 |
|------|--------|----------|------|----------|
| 사전 분류 | `query_class` | 노드 3 (LLM 정규화) | 검색 전략 결정, 내부DB 필요 여부 판단 | 노드 4 파싱 후 하류 노드 참조 가능 |
| 게이트 분기 | `QTYPE` | 노드 19 (LLM 답변생성 첫 줄) | 검열게이트 통과/차단 기준 | 노드 20 파이썬_검열게이트 |

### 값 매핑표

| query_class (노드 3) | QTYPE (노드 19/20) | 게이트 동작 |
|---------------------|-------------------|------------|
| `legal_analysis` | `LEGAL_JUDGMENT` | 항상 통과 (공식근거 0건이어도) |
| `internal_db_only` | `INTERNAL_ONLY` | 공식근거 0건이면 차단 |
| `mixed` | `HYBRID` | 공식근거 1건 이상이면 통과 |

### 불일치 발생 시 처리 원칙

- **노드 19/20의 QTYPE이 Canonical** (게이트 분기 기준)
- query_class는 검색 방향 힌트 역할 — 노드 20에서 직접 읽지 않음
- query_class=`legal_analysis`인데 QTYPE=`INTERNAL_ONLY`가 나오면 → 노드 19 프롬프트 재검토
- 두 값이 지속적으로 불일치하면 노드 3 프롬프트 규칙 강화 필요

---

## 20. 적용 후 검증 체크리스트

### 20-1. v2.1 DoD (완료 기준)

```text
[ ] 1. 노드 3 출력에 query_class + internal_db_required 컬럼 존재 확인
[ ] 2. QTYPE↔query_class 매핑 일치율 > 90% (테스트 10건 기준)
[ ] 3. AIHub 580 적재 시 노드 17 출력에 source_type 컬럼 정상 확인
[ ] 4. 판결문 Evidence: is_official=False, score 0.65~0.75 범위 확인
[ ] 5. 약관 Evidence: source_type="regulation_terms", is_official=False 확인
[ ] 6. LEGAL_JUDGMENT 질문 → 공식근거 0건이어도 is_pass=true 확인
[ ] 7. INTERNAL_ONLY 질문 → AIHub 판결문만 있을 때 is_pass=false 확인 (is_official=False이므로)
[ ] 8. 기존 테스트 10건 (섹션 8) 재통과 확인
[ ] 9. 테스트 로그 섹션 14 템플릿으로 기록
```

### 20-2. 노드별 빠른 확인 포인트

| 노드 | 확인 항목 | 정상값 |
|------|----------|--------|
| 노드 3 | `query_class` 값 | `legal_analysis` / `internal_db_only` / `mixed` 중 하나 |
| 노드 17 | `source_type` 값 | `law` / `precedent` / `interpretation` / `internal_case` / `regulation_terms` |
| 노드 18 | `score` 범위 | 법령 ≥ 1.0, 판례 ≈ 0.85~0.9, 로컬 AIHub ≈ 0.65~0.75 |
| 노드 20 | `is_pass` + `question_type` | LEGAL_JUDGMENT → is_pass=true 항상 |
| 노드 21 | 분기 방향 | is_pass=true → 노드 22(에이전트로 전달) |

---

## 21. 리스크 / 보류사항

### 21-1. 알려진 리스크

| 리스크 | 영향도 | 대응 |
|--------|--------|------|
| AIHub 580 로컬 파일 미확인 | 중 | 파일 수령 후 섹션 16 필드명 검증 필수 |
| query_class와 QTYPE 지속 불일치 | 중 | 노드 3 프롬프트 규칙 강화 또는 노드 4 파싱에서 query_class→QTYPE 변환 로직 추가 |
| AIHub 판결문의 is_official=False로 게이트 차단 | 중 | HYBRID/INTERNAL_ONLY 질문에서 공식 law.go.kr 근거 없을 때 차단 — 노드 19 QTYPE 분류 정확도가 핵심 |
| 약관 데이터 최신성 미보장 (2017/2020/2021 기준) | 낮 | 답변에 `[불확실/부재 — AIHub 580 기준]` 태그 권장 |
| law.go.kr API 간헐 장애 | 낮 | Worker 프록시 (섹션 10-1) 적용으로 흡수 |

### 21-2. 보류 항목 (재검토 조건)

| 보류 항목 | 재검토 조건 |
|----------|------------|
| 로컬 RAG (임베딩 벡터 DB) | law.go.kr API 실패율 > 20% 또는 오프라인 운영 필요 시 |
| AIHub 580 JSON/XML 자동 파싱 스크립트 | 로컬 파일 수령 후 실제 필드 구조 확인 시 |
| LawBot 스타일 코사인 유사도 필터 (0.5) | Evidence 스코어링 정밀도 개선 필요 시 |
| query_class → 노드 20 게이트 직접 연동 | QTYPE 추출 실패율 > 5% 관측 시 |

### 21-3. 미확인 사항 기록

```text
[미확인] AIHub 580 실제 XML 태그명 — 파일 수령 후 섹션 16 수정 필요
[미확인] AIHub 580 JSON 최상위 키 구조 — "약관명" 등 실제 필드명 미검증
[미확인] 2017/2020/2021 샘플 파일의 연도별 포맷 차이 여부
[가정]  판결문=XML, 약관=JSON 포맷 — 실제 확인 전까지 가정으로 취급
[가정]  로컬 AIHub 판결문 score 기본값 0.70 — 실제 데이터 품질 확인 후 조정
```
