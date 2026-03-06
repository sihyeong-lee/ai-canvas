# AI Canvas 법률 워크플로우 실행 런북 (최신 단일본)

최종 업데이트: 2026-03-05  
적용 범위: 법령/판례/행정해석 기반 질의응답 플로우(노드 1~23)

## 1. 원칙 (이 문서만 사용)

- 이 문서가 유일한 운영 기준이다.
- 초안/구버전/상충 지침은 모두 폐기한다.
- 기본 파이프라인: `질의 정규화 -> 목록 조회 -> 상세 조회 -> 근거 통합 -> 청킹 -> 관련도 필터 -> 답변 생성 -> 검열 게이트`.

## 2. 노드 순서(실행 기준)

1) 에이전트  
2) 에이전트 메시지 가로채기  
3) 에이전트 프롬프트_질의정규화  
4) 파이썬_정규화파싱  
5) 파이썬_URL생성  
6) API_법령목록  
7) API_판례목록  
8) API_해석목록  
9) 파이썬_법령상세URL_TOPK  
10) 파이썬_판례상세URL_TOPK  
11) 파이썬_해석상세URL_TOPK  
12) API_법령본문  
13) API_판례본문  
14) API_해석본문  
15) 데이터 연결_근거통합1  
16) 데이터 연결_근거통합2  
17) 파이썬_근거청킹  
18) 파이썬_관련도필터  
19) 에이전트 프롬프트_답변생성  
20) 파이썬_검열게이트  
21) 데이터 조건 분기  
22) 프롬프트_차단응답  
23) 에이전트로 전달

## 3. 공통 제약 (Python 노드)

- Python 노드는 `execute()` 내부 중간 코드만 입력한다.
- 중간 코드에 `import`, `return`, `yield`를 쓰지 않는다.
- 런타임이 `pd`, `json`, `re`를 제공한다는 전제로 작성한다.
- `oc=tud1211` 고정.
- query 이중 인코딩 금지 (`%25EC...` 금지).

## 4. 노드 4 코드 (정규화 파싱)

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

    law_query = str(obj.get("law_query", "") or "").strip()
    precedent_query = str(obj.get("precedent_query", "") or "").strip()
    interpretation_query = str(obj.get("interpretation_query", "") or "").strip()

    if not kws:
        fallback = " ".join([law_query, precedent_query, interpretation_query]).strip()
        if not fallback:
            fallback = str(row.get("query", "") or row.get("question", "") or "").strip()
        toks = [t for t in re.split(r"[,\s/|]+", fallback) if t]
        kws = [t.strip() for t in toks if len(t.strip()) >= 2][:7]

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
    elif not isinstance(must_have, list):
        must_have = []
    if not must_have:
        must_have = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]

    query_class = str(obj.get("query_class", "legal_analysis") or "legal_analysis").strip().lower()
    if query_class not in ["legal_analysis", "internal_db_only", "mixed"]:
        query_class = "legal_analysis"

    rows.append({
        "issue_keywords_csv": ", ".join(kws),
        "law_query": law_query,
        "precedent_query": precedent_query,
        "interpretation_query": interpretation_query,
        "date_from": str(obj.get("date_from", "") or "").strip(),
        "date_to": str(obj.get("date_to", "") or "").strip(),
        "must_have": ",".join(must_have),
        "query_class": query_class,
    })

result = pd.DataFrame(rows, columns=[
    "issue_keywords_csv", "law_query", "precedent_query", "interpretation_query",
    "date_from", "date_to", "must_have", "query_class",
])
```

## 5. 노드 5 코드 (목록 URL 생성)

중요: 기본은 직접 `law.go.kr` 경로. Worker는 선택 폴백.

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

use_worker = False
worker_base = "https://law-retry-proxy.<subdomain>.workers.dev"
direct_base = "http://www.law.go.kr"

base = direct_base
if use_worker:
    wb = "" if worker_base is None else str(worker_base).strip()
    if wb.endswith("/"):
        wb = wb[:-1]
    if wb:
        base = wb

_hex = "0123456789ABCDEF"
_safe = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_byte_to_char = {}
for i in range(256):
    _byte_to_char[i] = bytes([i]).decode("latin-1")

def _pct_encode(s):
    out = []
    for b in str(s).encode("utf-8"):
        ch = _byte_to_char[b]
        if b < 128 and ch in _safe:
            out.append(ch)
        else:
            out.append("%" + _hex[b >> 4] + _hex[b & 0xF])
    return "".join(out)

rows = []
for _, r in df.iterrows():
    fallback = str(r.get("issue_keywords_csv", "") or "").strip()
    if not fallback:
        fallback = "징계"

    lq = str(r.get("law_query", "") or "").strip() or fallback
    pq = str(r.get("precedent_query", "") or "").strip() or fallback
    eq = str(r.get("interpretation_query", "") or "").strip() or fallback

    if use_worker:
        law_url = f"{base}/drf/search?target=eflaw&query={_pct_encode(lq)}&display=5&page=1&sort=ddes&oc=tud1211"
        prec_url = f"{base}/drf/search?target=prec&query={_pct_encode(pq)}&display=5&page=1&sort=ddes&oc=tud1211"
        expc_url = f"{base}/drf/search?target=expc&query={_pct_encode(eq)}&display=5&page=1&sort=ddes&oc=tud1211"
    else:
        law_url = f"{base}/DRF/lawSearch.do?OC=tud1211&type=JSON&target=eflaw&search=1&query={_pct_encode(lq)}&display=5&page=1&sort=ddes"
        prec_url = f"{base}/DRF/lawSearch.do?OC=tud1211&type=JSON&target=prec&search=1&query={_pct_encode(pq)}&display=5&page=1&sort=ddes"
        expc_url = f"{base}/DRF/lawSearch.do?OC=tud1211&type=JSON&target=expc&search=1&query={_pct_encode(eq)}&display=5&page=1&sort=ddes"

    rows.append({
        "law_query_used": lq,
        "prec_query_used": pq,
        "expc_query_used": eq,
        "law_list_url": law_url,
        "prec_list_url": prec_url,
        "expc_list_url": expc_url,
        "api_method": "GET",
        "api_headers_json": "{}",
        "api_body": "",
    })

result = pd.DataFrame(rows, columns=[
    "law_query_used", "prec_query_used", "expc_query_used",
    "law_list_url", "prec_list_url", "expc_list_url",
    "api_method", "api_headers_json", "api_body",
])
```

## 6. 노드 9 코드 (법령 상세 URL TOP_K)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

use_worker = False
worker_base = "https://law-retry-proxy.<subdomain>.workers.dev"
direct_base = "http://www.law.go.kr"
TOP_K = 3

base = direct_base
if use_worker:
    wb = "" if worker_base is None else str(worker_base).strip()
    if wb.endswith("/"):
        wb = wb[:-1]
    if wb:
        base = wb

_hex = "0123456789ABCDEF"
_safe = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_byte_to_char = {}
for i in range(256):
    _byte_to_char[i] = bytes([i]).decode("latin-1")

def _pct(s):
    out = []
    for b in str(s).encode("utf-8"):
        ch = _byte_to_char[b]
        if b < 128 and ch in _safe:
            out.append(ch)
        else:
            out.append("%" + _hex[b >> 4] + _hex[b & 0xF])
    return "".join(out)

def _clean(v):
    if v is None:
        return ""
    s = str(v).strip()
    if (not s) or (s.lower() == "nan"):
        return ""
    if s.endswith(".0") and s[:-2].isdigit():
        s = s[:-2]
    return s

items = []
for _, r in df.iterrows():
    row = r.to_dict()
    found = False
    for key in ["LawSearch:law", "law", "data", "result", "rows", "items", "list", "body"]:
        bv = row.get(key, None)
        if isinstance(bv, list):
            for it in bv:
                if isinstance(it, dict):
                    items.append(it)
                    found = True
        elif isinstance(bv, dict):
            items.append(bv)
            found = True
        elif bv is not None:
            sv = str(bv).strip()
            if sv:
                try:
                    obj = json.loads(sv)
                    if isinstance(obj, list):
                        for it in obj:
                            if isinstance(it, dict):
                                items.append(it)
                                found = True
                    elif isinstance(obj, dict):
                        items.append(obj)
                        found = True
                except Exception:
                    pass
    if not found:
        items.append(row)

rows = []
for item in items:
    if len(rows) >= TOP_K:
        break

    mst = ""
    for k in ["MST", "mst", "법령일련번호", "법령MST"]:
        mst = _clean(item.get(k, ""))
        if mst:
            break

    idv = ""
    if not mst:
        for k in ["ID", "id", "법령ID", "law_id"]:
            idv = _clean(item.get(k, ""))
            if idv:
                break

    if use_worker:
        if mst:
            url = f"{base}/drf/detail?target=eflaw&MST={_pct(mst)}&oc=tud1211"
        elif idv:
            url = f"{base}/drf/detail?target=eflaw&ID={_pct(idv)}&oc=tud1211"
        else:
            url = ""
    else:
        if mst:
            url = f"{base}/DRF/lawService.do?OC=tud1211&target=eflaw&type=JSON&MST={_pct(mst)}"
        elif idv:
            url = f"{base}/DRF/lawService.do?OC=tud1211&target=eflaw&type=JSON&ID={_pct(idv)}"
        else:
            url = ""

    if url:
        rows.append({
            "law_detail_url": url,
            "api_method": "GET",
            "api_headers_json": "{}",
            "api_body": "",
        })

result = pd.DataFrame(rows, columns=["law_detail_url", "api_method", "api_headers_json", "api_body"])
```

## 7. 노드 10 코드 (판례 상세 URL TOP_K)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

use_worker = False
worker_base = "https://law-retry-proxy.<subdomain>.workers.dev"
direct_base = "http://www.law.go.kr"
TOP_K = 3

base = direct_base
if use_worker:
    wb = "" if worker_base is None else str(worker_base).strip()
    if wb.endswith("/"):
        wb = wb[:-1]
    if wb:
        base = wb

_hex = "0123456789ABCDEF"
_safe = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_byte_to_char = {}
for i in range(256):
    _byte_to_char[i] = bytes([i]).decode("latin-1")

def _pct(s):
    out = []
    for b in str(s).encode("utf-8"):
        ch = _byte_to_char[b]
        if b < 128 and ch in _safe:
            out.append(ch)
        else:
            out.append("%" + _hex[b >> 4] + _hex[b & 0xF])
    return "".join(out)

def _clean(v):
    if v is None:
        return ""
    s = str(v).strip()
    if (not s) or (s.lower() == "nan"):
        return ""
    if s.endswith(".0") and s[:-2].isdigit():
        s = s[:-2]
    return s

items = []
for _, r in df.iterrows():
    row = r.to_dict()
    found = False
    for key in ["PrecSearch:prec", "prec", "data", "result", "rows", "items", "list", "body"]:
        bv = row.get(key, None)
        if isinstance(bv, list):
            for it in bv:
                if isinstance(it, dict):
                    items.append(it)
                    found = True
        elif isinstance(bv, dict):
            items.append(bv)
            found = True
        elif bv is not None:
            sv = str(bv).strip()
            if sv:
                try:
                    obj = json.loads(sv)
                    if isinstance(obj, list):
                        for it in obj:
                            if isinstance(it, dict):
                                items.append(it)
                                found = True
                    elif isinstance(obj, dict):
                        items.append(obj)
                        found = True
                except Exception:
                    pass
    if not found:
        items.append(row)

rows = []
for item in items:
    if len(rows) >= TOP_K:
        break

    idv = ""
    for k in ["ID", "id", "판례정보일련번호", "판례일련번호", "prec_id"]:
        idv = _clean(item.get(k, ""))
        if idv:
            break

    if not idv:
        for k in ["판례상세링크", "detail_link", "link", "판례URL", "url", "URL"]:
            lv = _clean(item.get(k, ""))
            if lv.startswith("http"):
                m = re.search(r"[&?]ID=([^&\s]+)", lv)
                if m:
                    idv = _clean(m.group(1))
                    break

    if idv:
        if use_worker:
            url = f"{base}/drf/detail?target=prec&ID={_pct(idv)}&oc=tud1211"
        else:
            url = f"{base}/DRF/lawService.do?OC=tud1211&target=prec&type=JSON&ID={_pct(idv)}"
        rows.append({
            "prec_detail_url": url,
            "api_method": "GET",
            "api_headers_json": "{}",
            "api_body": "",
        })

result = pd.DataFrame(rows, columns=["prec_detail_url", "api_method", "api_headers_json", "api_body"])
```

## 8. 노드 11 코드 (해석 상세 URL TOP_K)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

use_worker = False
worker_base = "https://law-retry-proxy.<subdomain>.workers.dev"
direct_base = "http://www.law.go.kr"
TOP_K = 3

base = direct_base
if use_worker:
    wb = "" if worker_base is None else str(worker_base).strip()
    if wb.endswith("/"):
        wb = wb[:-1]
    if wb:
        base = wb

_hex = "0123456789ABCDEF"
_safe = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
_byte_to_char = {}
for i in range(256):
    _byte_to_char[i] = bytes([i]).decode("latin-1")

def _pct(s):
    out = []
    for b in str(s).encode("utf-8"):
        ch = _byte_to_char[b]
        if b < 128 and ch in _safe:
            out.append(ch)
        else:
            out.append("%" + _hex[b >> 4] + _hex[b & 0xF])
    return "".join(out)

def _clean(v):
    if v is None:
        return ""
    s = str(v).strip()
    if (not s) or (s.lower() == "nan"):
        return ""
    if s.endswith(".0") and s[:-2].isdigit():
        s = s[:-2]
    return s

items = []
for _, r in df.iterrows():
    row = r.to_dict()
    found = False
    for key in ["Expc:expc", "expc", "data", "result", "rows", "items", "list", "body"]:
        bv = row.get(key, None)
        if isinstance(bv, list):
            for it in bv:
                if isinstance(it, dict):
                    items.append(it)
                    found = True
        elif isinstance(bv, dict):
            items.append(bv)
            found = True
        elif bv is not None:
            sv = str(bv).strip()
            if sv:
                try:
                    obj = json.loads(sv)
                    if isinstance(obj, list):
                        for it in obj:
                            if isinstance(it, dict):
                                items.append(it)
                                found = True
                    elif isinstance(obj, dict):
                        items.append(obj)
                        found = True
                except Exception:
                    pass
    if not found:
        items.append(row)

rows = []
for item in items:
    if len(rows) >= TOP_K:
        break

    idv = ""
    for k in ["ID", "id", "행정해석ID", "법령해석례일련번호", "expc_id"]:
        idv = _clean(item.get(k, ""))
        if idv:
            break

    if not idv:
        for k in ["해석상세링크", "detail_link", "link", "해석URL", "url", "URL"]:
            lv = _clean(item.get(k, ""))
            if lv.startswith("http"):
                m = re.search(r"[&?]ID=([^&\s]+)", lv)
                if m:
                    idv = _clean(m.group(1))
                    break

    if idv:
        if use_worker:
            url = f"{base}/drf/detail?target=expc&ID={_pct(idv)}&oc=tud1211"
        else:
            url = f"{base}/DRF/lawService.do?OC=tud1211&target=expc&type=JSON&ID={_pct(idv)}"
        rows.append({
            "expc_detail_url": url,
            "api_method": "GET",
            "api_headers_json": "{}",
            "api_body": "",
        })

result = pd.DataFrame(rows, columns=["expc_detail_url", "api_method", "api_headers_json", "api_body"])
```

## 9. Custom API 고정 설정 (노드 6/7/8/12/13/14)

- 요청 모드: `데이터셋 요청`
- URL 컬럼:
  - 노드 6: `law_list_url`
  - 노드 7: `prec_list_url`
  - 노드 8: `expc_list_url`
  - 노드 12: `law_detail_url`
  - 노드 13: `prec_detail_url`
  - 노드 14: `expc_detail_url`
- Method 컬럼: `api_method`
- Headers 컬럼: `api_headers_json`
- Body 컬럼: `api_body`
- 자동 변환(JSON<->CSV): `ON`

필수 컬럼(항상 포함):
- `api_method` (값: `GET`)
- `api_headers_json` (값: `{}`)
- `api_body` (값: 빈 문자열)

## 10. 노드 17 코드 (근거 청킹)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

chunk_size = 700
stride = 560
text_min_len = 40

rows = []
for _, r in df.iterrows():
    row = r.to_dict()

    src = ""
    for k in ["target", "source_type", "api_target", "노드명"]:
        if k in row:
            v = row.get(k, "")
            v = "" if v is None else str(v).strip()
            if v and v.lower() != "nan":
                src = v
                break
    if not src:
        src = "unknown"

    url = ""
    for k in ["url", "source_url", "law_detail_url", "prec_detail_url", "expc_detail_url", "상세링크"]:
        if k in row:
            v = row.get(k, "")
            v = "" if v is None else str(v).strip()
            if v and v.lower() != "nan":
                url = v
                break

    text_candidates = []
    for k in row.keys():
        kk = str(k)
        vv = row.get(k, "")
        if vv is None:
            continue
        try:
            if pd.isna(vv):
                continue
        except Exception:
            pass
        sv = str(vv).strip()
        if not sv or sv.lower() == "nan":
            continue
        if sv.startswith("http://") or sv.startswith("https://"):
            continue
        if len(sv) < text_min_len:
            continue
        if kk in ["api_method", "api_headers_json", "api_body", "issue_keywords_csv", "law_query", "precedent_query", "interpretation_query", "question_prompt", "query"]:
            continue
        text_candidates.append(sv)

    merged = "\n\n".join(text_candidates)
    if not merged:
        continue

    qclass = row.get("query_class", "legal_analysis")
    qclass = "legal_analysis" if qclass is None else str(qclass).strip().lower()
    if qclass not in ["legal_analysis", "internal_db_only", "mixed"]:
        qclass = "legal_analysis"

    i = 0
    order = 0
    n = len(merged)
    while i < n:
        piece = merged[i:i+chunk_size].strip()
        if piece:
            rows.append({
                "query_class": qclass,
                "issue_keywords_csv": row.get("issue_keywords_csv", ""),
                "law_query": row.get("law_query", ""),
                "precedent_query": row.get("precedent_query", ""),
                "interpretation_query": row.get("interpretation_query", ""),
                "question_prompt": row.get("question_prompt", row.get("query", "")),
                "source_type": src,
                "source_url": url,
                "chunk_order": int(order),
                "chunk_text": piece,
            })
            order += 1
        if i + chunk_size >= n:
            break
        i += stride

result = pd.DataFrame(rows, columns=[
    "query_class", "issue_keywords_csv", "law_query", "precedent_query", "interpretation_query",
    "question_prompt", "source_type", "source_url", "chunk_order", "chunk_text",
])
```

## 11. 노드 18 코드 (관련도 필터)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

keys = []
for c in ["issue_keywords_csv", "law_query", "precedent_query", "interpretation_query", "question_prompt", "query"]:
    if c in df.columns:
        for v in df[c].tolist():
            s = "" if v is None else str(v).strip()
            if s and s.lower() != "nan":
                keys.extend([x.strip() for x in s.replace("/", " ").replace(",", " ").split(" ") if x.strip()])

uniq = []
for k in keys:
    if len(k) < 2:
        continue
    if k not in uniq:
        uniq.append(k)

if not uniq:
    uniq = ["징계"]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    txt = row.get("chunk_text", "")
    txt = "" if txt is None else str(txt)
    if not txt.strip():
        continue

    score = 0
    for k in uniq:
        if k in txt:
            score += 1

    rows.append({
        "query_class": row.get("query_class", "legal_analysis"),
        "source_type": row.get("source_type", "unknown"),
        "source_url": row.get("source_url", ""),
        "chunk_text": txt,
        "score": int(score),
    })

ranked = pd.DataFrame(rows)
if ranked.empty:
    result = pd.DataFrame(columns=["query_class", "evidence_context", "source_urls", "official_evidence_count"])
else:
    ranked = ranked.sort_values(by=["score"], ascending=False).reset_index(drop=True)
    top_k = ranked.head(12).copy()

    evidence_lines = []
    urls = []
    official = 0

    for _, rr in top_k.iterrows():
        st = "" if rr.get("source_type", "") is None else str(rr.get("source_type", "")).strip()
        su = "" if rr.get("source_url", "") is None else str(rr.get("source_url", "")).strip()
        tx = "" if rr.get("chunk_text", "") is None else str(rr.get("chunk_text", "")).strip()
        sc = rr.get("score", 0)

        if su:
            if su not in urls:
                urls.append(su)
            if "law.go.kr" in su or "scourt.go.kr" in su or "workers.dev" in su:
                official += 1

        if tx:
            evidence_lines.append(f"[{st}|score={sc}] {tx[:600]}")

    qclass = "legal_analysis"
    if "query_class" in top_k.columns and len(top_k) > 0:
        qv = top_k.iloc[0]["query_class"]
        qclass = "legal_analysis" if qv is None else str(qv).strip().lower()
        if qclass not in ["legal_analysis", "internal_db_only", "mixed"]:
            qclass = "legal_analysis"

    result = pd.DataFrame([{
        "query_class": qclass,
        "evidence_context": "\n\n".join(evidence_lines),
        "source_urls": " | ".join(urls),
        "official_evidence_count": int(official),
    }])
```

## 12. 노드 20 코드 (검열 게이트)

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

for c in ["output_response", "output_response_1", "draft_answer", "result_text", "answer", "text"]:
    if c in df.columns:
        ans_col = c
        break
else:
    ans_col = None

for c in ["query_class", "query_type", "qtype"]:
    if c in df.columns:
        q_col = c
        break
else:
    q_col = None

for c in ["official_evidence_count", "official_count"]:
    if c in df.columns:
        off_col = c
        break
else:
    off_col = None

for c in ["internal_evidence_count", "internal_count"]:
    if c in df.columns:
        in_col = c
        break
else:
    in_col = None

for c in ["source_urls", "urls"]:
    if c in df.columns:
        url_col = c
        break
else:
    url_col = None

deny_domains = ["namu.wiki", "blog.naver.com", "tistory.com"]

rows = []
for _, r in df.iterrows():
    row = r.to_dict()

    text = str(row.get(ans_col, "") if ans_col else "").strip()
    qclass = str(row.get(q_col, "legal_analysis") if q_col else "legal_analysis").strip().lower()
    if qclass not in ["legal_analysis", "internal_db_only", "mixed"]:
        qclass = "legal_analysis"

    try:
        official = int(float(str(row.get(off_col, 0) if off_col else 0).strip()))
    except Exception:
        official = 0
    try:
        internal = int(float(str(row.get(in_col, 0) if in_col else 0).strip()))
    except Exception:
        internal = 0

    src_urls = str(row.get(url_col, "") if url_col else "")
    lower_urls = src_urls.lower()

    has_deny_domain = False
    for d in deny_domains:
        if d in lower_urls:
            has_deny_domain = True
            break

    has_text = bool(text)
    is_pass = False
    reason = ""

    if has_deny_domain:
        reason = "금지 도메인 포함"
    elif qclass == "legal_analysis":
        if has_text:
            is_pass = True
        else:
            reason = "답변 텍스트 없음"
    elif qclass == "internal_db_only":
        if has_text and internal >= 1:
            is_pass = True
        else:
            reason = "internal_db_only 조건 미충족"
    else:
        if has_text and (official >= 1 or internal >= 1):
            is_pass = True
        else:
            reason = "mixed 조건 미충족"

    rows.append({
        "is_pass": bool(is_pass),
        "fail_reason": reason,
        "query_class": qclass,
        "official_evidence_count": int(official),
        "internal_evidence_count": int(internal),
        "output_response": text,
        "source_urls": src_urls,
    })

result = pd.DataFrame(rows, columns=[
    "is_pass", "fail_reason", "query_class", "official_evidence_count",
    "internal_evidence_count", "output_response", "source_urls",
])
```

## 13. Data Connect 2입력 체인 설정 (노드 15, 16)

노드 15 `데이터 연결_근거통합1`:
- 입력1: 노드12(API_법령본문)
- 입력2: 노드13(API_판례본문)
- 축(axis) 권장: `수직`
- 병합 모드(merge mode) 권장: `모든 열 사용`
- 대상 레이블(target label) 권장: `None(비움)`

노드 16 `데이터 연결_근거통합2`:
- 입력1: 노드15 출력
- 입력2: 노드14(API_해석본문)
- 축(axis) 권장: `수직`
- 병합 모드(merge mode) 권장: `모든 열 사용`
- 대상 레이블(target label) 권장: `None(비움)`

대안:
- 대안 1: 축 `수직` + 병합 `공통 열 사용` (권장하지 않음: 본문 컬럼 누락 위험)
- 대안 2: target label을 `source_type`로 지정 (출처 추적 강화, 대신 컬럼 관리 증가)

## 14. Worker 사용 결정 (필수 정책)

- 기본 운영: 직접 `law.go.kr` 경로 사용 (`/DRF/lawSearch.do`, `/DRF/lawService.do`).
- Worker는 선택적 폴백으로만 사용.
- 전환 기준: 직접 경로에서 연속 네트워크 실패/HTML 챌린지/timeout이 반복될 때만 `use_worker=True`로 전환.

참조 파일(유지):
- `retry_proxy_cloudflare_worker.js`
- `retry_proxy_setup.md`

## 15. 사용자 출력 품질 (로봇톤 방지)

노드 19 프롬프트에 다음 가이드를 고정한다.
- 답변 구조: `핵심 결론 -> 판단 기준 -> 실무 체크리스트 -> 불확실/추가확인`.
- 금지: "부재", "확인불가"를 문장마다 반복 나열.
- 허용: 불확실 정보는 마지막에 1개 묶음 섹션으로만 정리.
- 톤: 단문 나열 대신 설명형 문장 + 실행 가능한 포인트 제시.

노드 20 게이트 운영 가이드:
- 텍스트가 비어있지 않으면 즉시 탈락시키지 말고, 금지 도메인/증거 조건만 점검.
- `legal_analysis`는 공식근거 개수가 0이어도 설명형 답변 통과 허용.
- `internal_db_only`, `mixed`만 증거 개수 조건을 엄격 적용.

## 16. 실행 순서 체크리스트

1) 노드 3, 4, 5 실행 후 `law_query/precedent_query/interpretation_query` 생성 확인  
2) 노드 6, 7, 8 실행 후 목록 응답 JSON 유효성 확인  
3) 노드 9, 10, 11 실행 후 상세 URL이 각 소스별 최대 3건 생성되는지 확인  
4) 노드 12, 13, 14 실행 후 본문 텍스트 필드 유입 확인  
5) 노드 15, 16 실행 후 행 수 감소/유실 여부 확인  
6) 노드 17 실행 후 `chunk_text` 생성 확인  
7) 노드 18 실행 후 `evidence_context`, `source_urls` 확인  
8) 노드 19 실행 후 서술형 답변 품질 확인  
9) 노드 20 실행 후 `is_pass` 확인  
10) 노드 21 분기 -> 노드 22 또는 23 정상 전달 확인

## 17. 장애 복구 체크리스트

1) URL 생성 점검: `%25` 포함 시 즉시 수정(이중 인코딩)  
2) Custom API 컬럼 점검: `api_method/api_headers_json/api_body` 누락 시 채움  
3) 상세 ID/MST 점검: 노드 9~11 추출 키 확인  
4) Data Connect 설정 점검: `수직 + 모든 열 + target None`으로 복귀  
5) Worker 모드 점검: 직접 경로 실패가 반복될 때만 `use_worker=True`  
6) 게이트 점검: `fail_reason` 원인 먼저 수정 후 재실행

## 18. 분기 노드 고정

- 노드 21: Left=`is_pass`, Right=`true`
- 노드 22(차단응답) 템플릿:

```text
1) 현재 조회된 근거 범위에서 결론을 확정하지 않습니다.
2) 기간/사실관계/키워드를 보강해 다시 질의해 주세요.
3) 불확실/부재 항목: {{fail_reason}}
```

- 노드 23: 전달 컬럼은 `output_response`(또는 환경에 따라 `output_response_1`)만 사용

## 19. Worker 배포/헬스 체크 (선택 폴백용)

목적:
- 직접 `law.go.kr` 경로가 반복 실패할 때만 보조 경로로 사용.

배포:
1) Cloudflare `Workers & Pages` -> `Create` -> `Start with Hello World!`  
2) Worker 이름 생성(예: `law-retry-proxy`)  
3) 기본 코드 전체 삭제 후 `retry_proxy_cloudflare_worker.js` 붙여넣기  
4) Deploy

헬스 체크:
- `https://<worker-subdomain>/health`
- 기대값: `{"ok":true,"service":"law-retry-proxy",...}`

주의:
- `/drf/search`, `/drf/detail` 경로만 정상 엔드포인트다.
- Worker에서 `upstream_status_525`, `timeout`이 반복되면 즉시 직접 경로로 복귀한다.

## 20. 재실행 규칙 (중요)

- 전체 재실행 금지. 실패 노드만 재실행.
- 권장 재시도 횟수: 같은 노드 최대 2회.
- 순서:
1) 6~8 실패 시: 실패한 목록 노드만 재실행
2) 9~11 실패 시: 해당 URL생성 노드만 재실행
3) 12~14 실패 시: 해당 본문 API 노드만 재실행
4) 15/16 실패 시: Data Connect 설정 복구 후 해당 노드만 재실행
5) 20 실패 시: `query_class`, `official_evidence_count`, `internal_evidence_count` 우선 확인

## 21. 오류코드 즉시 조치표

- `sequence item 0: expected str instance, NoneType found`
  - 원인: Custom API method/header/body 컬럼 누락 또는 빈값
  - 조치: `api_method/api_headers_json/api_body` 3컬럼을 출력/매핑 고정

- `Not allowed context: import ...`
  - 원인: Python 노드 중간 코드에 import 사용
  - 조치: import 제거, 제공 런타임 변수만 사용

- `Not allowed context: return or yield`
  - 원인: Python 노드 중간 코드에서 return/yield 사용
  - 조치: `result = pd.DataFrame(...)`만 남김

- `비정상적인 URL이 포함되어 있습니다`
  - 원인: 상세 URL 빈값 또는 깨진 URL
  - 조치: 노드 9~11의 MST/ID 추출값 확인 후 URL 재생성

- `[Errno 104] Connection reset by peer`
  - 원인: 외부 API 연결 리셋
  - 조치: 해당 노드 1~2회 재시도, 지속되면 잠시 대기 후 재실행

- Worker `upstream_status_525` / `timeout`
  - 원인: Worker->upstream 연결 불안정
  - 조치: Worker 비활성화(`use_worker=False`) 후 직접 경로 사용

## 22. 운영 수용 기준 (DoD)

아래 6개를 모두 만족하면 완료:
1) 노드 6~8 목록 API 모두 1회 이상 성공
2) 노드 9~11 상세 URL이 빈값 없이 생성
3) 노드 12~14 본문 텍스트 유입 확인
4) 노드 17~18에서 `evidence_context`, `source_urls` 생성
5) 노드 20 `is_pass=True` 또는 차단 사유가 실제 규칙과 일치
6) 노드 23 최종 전달이 `output_response`로 정상 출력

## 23. 회귀 테스트 질의 10개

1) 직장 내 괴롭힘 요건과 입증 포인트를 알려줘  
2) 징계해고 정당성 판단 요소를 체크리스트로 정리해줘  
3) 감봉 처분 시 절차상 필수 요건을 알려줘  
4) 취업규칙상 징계위원회 절차 하자 사례를 설명해줘  
5) 무단결근 3일에 대한 징계 양정이 적정한지 검토해줘  
6) 회사 징계시효 기산점은 언제로 보는지 알려줘  
7) 내부 징계DB 기준으로 2025년 징계해고 건수 요약해줘  
8) 내부 DB와 공식 근거가 상충할 때 판단 원칙을 알려줘  
9) 공공기관 인사징계와 민간기업 징계 기준 차이를 설명해줘  
10) 징계처분 불복 절차를 단계별로 알려줘

## 24. 마지막 고정값 요약

- Custom API: method=`api_method`, headers=`api_headers_json`, body=`api_body`
- Data Connect(15/16): axis=`수직`, merge=`모든 열 사용`, target label=`None`
- URL 생성: 이중 인코딩 금지 (`%25` 금지)
- 기본 경로: 직접 `law.go.kr`
- Worker: 선택 폴백(반복 실패 시만 사용)

## 25. AIHub 데이터셋(580) + LawBot 참고 적용

### 25.1 AIHub Open API 해석(이 문서 기준)

- 본 운영 문맥에서 AIHub Open API는 `aihubshell` 기반의 **데이터셋 파일 다운로드/동기화 경로**를 의미한다.
- 즉시 법률 질의응답을 반환하는 실시간 추론 API로 간주하지 않는다.
- 질의응답 추론은 기존 AI Canvas 노드 플로우(노드 1~23)에서 수행한다.
- 다운로드 전제: 데이터셋 승인 완료 + API key 발급 완료가 필요하다.

### 25.2 AI Canvas 통합 경로

A) 오프라인 배치 적재(권장):
1) AIHub에서 승인 완료된 파일 다운로드
2) 전처리(텍스트 정규화, 메타 추출, 출처 URL 보정)
3) 로컬 증거 테이블 생성(`source_type/source_url/chunk_text` 중심)
4) 기존 노드 17(청킹) -> 노드 18(관련도필터) 근거 흐름으로 투입
5) 노드 19(답변생성) + 노드 20(검열게이트) 정책 그대로 적용

B) 온라인 fetch 노드(선택):
- 향후 AIHub 측에 안정적인 온라인 조회 endpoint가 제공될 때만 추가한다.
- 추가 시에도 최종 출력 계약은 동일하게 `증거 테이블 -> 노드 17/18 -> 노드 19/20`을 유지한다.

### 25.3 aihubshell 실무 명령(키 마스킹)

사전 조건:
- AIHub 사이트에서 대상 데이터셋 승인 완료
- `aihubshell` 실행 가능 상태
- Linux/WSL 환경 권장

명령 패턴:

```bash
# 1) aihubshell 다운로드
curl -o "aihubshell" https://api.aihub.or.kr/api/aihubshell.do
chmod +x aihubshell

# 2) 도움말
aihubshell -help

# 3) 전체 데이터셋 목록 조회
aihubshell -mode l

# 4) 목록 검색(법률/규정/580)
aihubshell -mode l | grep -E "법률|규정|580|판결서"

# 5) 대상 datasetkey 확인 후 파일 트리/파일키 조회
aihubshell -mode l -datasetkey <datasetkey>

# 6) 전체 다운로드(승인 필요)
aihubshell -mode d -datasetkey <datasetkey> -aihubapikey 'AIHUB-APIKEY-****-****'

# 7) 선택 다운로드(filekey 1개)
aihubshell -mode d -datasetkey <datasetkey> -filekey 12345 -aihubapikey 'AIHUB-APIKEY-****-****'

# 8) 선택 다운로드(filekey 여러 개)
aihubshell -mode d -datasetkey <datasetkey> -filekey 12345,12346,12347 -aihubapikey 'AIHUB-APIKEY-****-****'
```

`datasetkey/filekey` 메모:
- `datasetkey`: 데이터셋 식별자(`-mode l` 결과에서 확인, 데이터 상세 페이지 번호와 다를 수 있음)
- `filekey`: `-mode l -datasetkey <datasetkey>` 출력에서 확인하는 개별 파일 식별자
- `-filekey` 생략 시 데이터셋 전체 다운로드

### 25.4 LawBot 레퍼런스 적용 (로컬 폴더 기준)

참조 근거:
- `LawBot-Online-Legal-Advice-LLM-Service-main/backend/app/filter.py`
- `LawBot-Online-Legal-Advice-LLM-Service-main/backend/app/main.py`
- `LawBot-Online-Legal-Advice-LLM-Service-main/backend/app/search.py`

적용 아이디어:
1) 법률질문 필터 게이트
- LawBot의 `is_legal_question()`처럼 비법률 질문을 초기에 차단/분기
- AI Canvas 매핑: 노드 3(질의정규화)에서 `query_class` 보강 + 노드 20(검열게이트) 분기 규칙 강화

2) 검색 + 판례 유사도
- LawBot의 임베딩+코사인 유사도 기반 상위 사례 추출 로직을 참고
- AI Canvas 매핑: 노드 17(청킹)에서 검색 단위 표준화, 노드 18(관련도필터)에서 점수화/Top-K 선별

3) 답변 생성 + 판례/법령 링크 포함
- LawBot처럼 답변과 함께 유사 판례 리스트/관련 법령 링크를 제공
- AI Canvas 매핑: 노드 19에서 본문 답변 생성, 노드 18의 `source_urls`를 근거 링크로 결합

4) 노드별 책임 분리(현재 플로우 유지)
- 노드 3/4: 질문 분석 + 분류 신호
- 노드 6~14: 공식 근거 수집
- 노드 17/18: 검색/유사도/증거 압축
- 노드 19: 생성
- 노드 20~23: 안전 분기 및 최종 전달

### 25.5 보안 메모(API 키)

- API 키를 문서/코드/노드 상수에 하드코딩하지 않는다.
- 운영 시 환경변수 또는 시크릿 저장소를 사용한다.
- 예시(쉘): `AIHUB_API_KEY=...` 또는 플랫폼 시크릿에 등록 후 런타임 주입.

### 25.6 결론: 둘 다 필요하다 (용도만 다름)

- AIHub Open API(`aihubshell`): **데이터 수집/동기화용**으로 필요
- LawBot GitHub: **질문분류 + 유사사례 검색 + 답변결합 구조 참고용**으로 필요
- 즉, 둘 다 "불필요"가 아니라, 실시간 추론 API처럼 바로 붙는 대상이 아니라는 뜻이다.

### 25.7 지금 바로 체감되는 적용(필수)

현재 워크플로우에 아래 2개를 추가하면 AIHub/내부DB 근거가 실제 답변에 들어간다.

1) 노드 `16A. 파이썬_내부DB정규화` 추가  
2) 노드 `16B. 데이터 연결_근거통합3` 추가 (노드16 + 노드16A 병합)

연결 순서:
- 기존: `... -> 노드16(법령/판례/해석 통합) -> 노드17`
- 변경: `... -> 노드16` + `내부DB업로드 -> 노드16A` -> `노드16B` -> `노드17`

`노드16A` 파이썬 코드(중간 코드):

```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

def _pick(row, keys):
    for k in keys:
        if k in row:
            v = row.get(k, "")
            if v is None:
                continue
            s = str(v).strip()
            if s and s.lower() != "nan":
                return s
    return ""

rows = []
for row in df.to_dict(orient="records"):
    title = _pick(row, ["사건명", "제목", "title", "case_name"])
    text = _pick(row, [
        "판결요지", "판시사항", "판결문", "본문", "내용",
        "text", "document", "chunk_text", "evidence_text"
    ])
    if not text:
        continue

    url = _pick(row, ["source_url", "참조URL", "링크", "url"])
    case_no = _pick(row, ["사건번호", "case_number"])
    kwords = _pick(row, ["키워드", "keywords", "issue_keywords_csv"])
    dt = _pick(row, ["선고일", "date", "incident_date"])

    rows.append({
        "source_type": "internal_db",
        "case_title": title,
        "case_number": case_no,
        "date": dt,
        "source_url": url,
        "keywords": kwords,
        "evidence_text": text
    })

result = pd.DataFrame(rows, columns=[
    "source_type", "case_title", "case_number", "date",
    "source_url", "keywords", "evidence_text"
])
```

`노드16B(데이터 연결_근거통합3)` 설정:
- 입력1: 노드16 출력
- 입력2: 노드16A 출력
- 축(axis): `수직`
- 병합 방식: `모든 열 사용`
- 대상 레이블: `None(비움)`

`노드17` 입력은 노드16B로 변경한다.

### 25.8 LawBot 구조를 현재 노드에 강제 매핑

- LawBot `filter.py`(법률질문 판별)  
  -> 현재 노드3/노드20의 `query_class` 분기에 반영

- LawBot `search.py`(유사 판례 Top-K)  
  -> 현재 노드18 관련도 필터 Top-K 정책으로 반영

- LawBot `main.py`(필터->검색->생성 파이프)  
  -> 현재 노드 순서 `3/4 -> 6~18 -> 19 -> 20`와 동일한 책임 분리 유지

### 25.9 적용 후 검증 포인트

아래 3개가 보이면 반영 성공:
1) 노드16A 출력에 `source_type=internal_db` 행 존재
2) 노드18 `evidence_context`에 내부DB 텍스트 일부 포함
3) 노드19 최종답변에서 내부DB 근거를 참조한 문장 출력
