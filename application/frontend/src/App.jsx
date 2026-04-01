import { useState, useEffect } from 'react';

const API_BASE = '';

const styles = `
  @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=Syne:wght@400;600;700&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: #0a0a0f;
    color: #e2e2e8;
    font-family: 'Syne', sans-serif;
    min-height: 100vh;
  }

  .dashboard {
    min-height: 100vh;
    background: #0a0a0f;
    background-image:
      radial-gradient(ellipse 80% 50% at 50% -20%, rgba(99,102,241,0.15) 0%, transparent 60%),
      linear-gradient(180deg, #0a0a0f 0%, #0d0d14 100%);
    padding: 48px 24px;
  }

  .container {
    max-width: 680px;
    margin: 0 auto;
  }

  /* KT Cloud 배너 */
  .kt-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 20px;
    margin-bottom: 32px;
    background: linear-gradient(135deg, #111118 0%, #16161f 100%);
    border: 1px solid #1e1e2a;
    border-radius: 10px;
    overflow: hidden;
    position: relative;
  }
  .kt-banner::before {
    content: '';
    position: absolute;
    left: 0; top: 0; bottom: 0;
    width: 3px;
    background: linear-gradient(180deg, #e8412a, #f97316);
  }
  .kt-banner-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .kt-logo {
    font-family: 'Syne', sans-serif;
    font-size: 13px;
    font-weight: 700;
    color: #e8412a;
    letter-spacing: 0.04em;
    line-height: 1;
  }
  .kt-divider {
    width: 1px;
    height: 18px;
    background: #2a2a38;
  }
  .kt-course {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: #71717a;
    letter-spacing: 0.06em;
  }
  .kt-course span {
    color: #a1a1aa;
  }
  .kt-team {
    font-family: 'Syne', sans-serif;
    font-size: 12px;
    font-weight: 700;
    color: #6366f1;
    letter-spacing: 0.04em;
    background: rgba(99,102,241,0.1);
    border: 1px solid rgba(99,102,241,0.2);
    padding: 4px 10px;
    border-radius: 6px;
  }

  /* 헤더 */
  .header {
    margin-bottom: 40px;
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
  }

  .header-left {}
  .header-eyebrow {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    letter-spacing: 0.12em;
    color: #6366f1;
    text-transform: uppercase;
    margin-bottom: 8px;
  }

  .header-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 10px;
  }
  .meta-tag {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    letter-spacing: 0.06em;
    padding: 3px 9px;
    border-radius: 4px;
  }
  .meta-tag.kt {
    color: #a78bfa;
    background: rgba(167,139,250,0.1);
    border: 1px solid rgba(167,139,250,0.2);
  }
  .meta-tag.team {
    color: #34d399;
    background: rgba(52,211,153,0.1);
    border: 1px solid rgba(52,211,153,0.2);
  }
  .header-title {
    font-size: 28px;
    font-weight: 700;
    color: #f0f0f5;
    line-height: 1.2;
    letter-spacing: -0.02em;
  }
  .header-title span {
    color: #6366f1;
  }

  .live-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: #52525b;
    letter-spacing: 0.06em;
    padding-top: 6px;
    flex-shrink: 0;
  }
  .live-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #52525b;
    transition: background 0.4s;
  }
  .live-dot.healthy {
    background: #22c55e;
    box-shadow: 0 0 8px #22c55e88;
    animation: pulse 2s ease-in-out infinite;
  }
  .live-dot.error {
    background: #ef4444;
    box-shadow: 0 0 8px #ef444488;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  /* 상태 카드 */
  .status-card {
    background: #111118;
    border: 1px solid #1e1e2a;
    border-radius: 12px;
    padding: 20px 24px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    transition: border-color 0.3s;
  }
  .status-card:hover { border-color: #2a2a38; }

  .status-left {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .status-icon-wrap {
    width: 38px;
    height: 38px;
    border-radius: 8px;
    background: #1a1a24;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    flex-shrink: 0;
  }
  .status-info {}
  .status-label {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 10px;
    color: #52525b;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    margin-bottom: 4px;
  }
  .status-value {
    font-size: 14px;
    font-weight: 600;
    color: #a1a1aa;
    transition: color 0.3s;
  }
  .status-value.healthy { color: #22c55e; }
  .status-value.error { color: #ef4444; }
  .status-value.checking { color: #f59e0b; }

  /* 버튼 */
  .btn-ghost {
    background: transparent;
    border: 1px solid #2a2a38;
    color: #71717a;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    letter-spacing: 0.06em;
    padding: 8px 14px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
  }
  .btn-ghost:hover {
    border-color: #6366f1;
    color: #a5b4fc;
    background: rgba(99,102,241,0.06);
  }

  /* 액션 버튼 그룹 */
  .action-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin-bottom: 24px;
  }

  .btn-primary {
    background: linear-gradient(135deg, #6366f1, #4f46e5);
    border: none;
    color: #fff;
    font-family: 'Syne', sans-serif;
    font-size: 14px;
    font-weight: 600;
    padding: 14px 20px;
    border-radius: 10px;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    letter-spacing: -0.01em;
    box-shadow: 0 4px 20px rgba(99,102,241,0.25);
  }
  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 6px 28px rgba(99,102,241,0.4);
  }
  .btn-primary:active { transform: translateY(0); }

  .btn-secondary {
    background: #111118;
    border: 1px solid #2a2a38;
    color: #a1a1aa;
    font-family: 'Syne', sans-serif;
    font-size: 14px;
    font-weight: 600;
    padding: 14px 20px;
    border-radius: 10px;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    letter-spacing: -0.01em;
  }
  .btn-secondary:hover {
    border-color: #3f3f52;
    color: #e2e2e8;
    background: #16161f;
  }

  /* 데이터 패널 */
  .panel {
    background: #111118;
    border: 1px solid #1e1e2a;
    border-radius: 12px;
    overflow: hidden;
  }
  .panel-header {
    padding: 18px 24px;
    border-bottom: 1px solid #1e1e2a;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .panel-title {
    font-size: 13px;
    font-weight: 600;
    color: #e2e2e8;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .panel-count {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: #52525b;
    background: #1a1a24;
    padding: 3px 8px;
    border-radius: 4px;
  }

  /* 데이터 리스트 */
  .data-list { list-style: none; }

  .data-item {
    padding: 14px 24px;
    border-bottom: 1px solid #16161f;
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: 16px;
    transition: background 0.15s;
  }
  .data-item:last-child { border-bottom: none; }
  .data-item:hover { background: #13131c; }
  .data-item.first { background: rgba(99,102,241,0.04); }
  .data-item.first:hover { background: rgba(99,102,241,0.07); }

  .data-index {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: #3f3f52;
    width: 20px;
    text-align: right;
  }
  .data-item.first .data-index { color: #6366f1; }

  .data-body {}
  .data-id {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 11px;
    color: #52525b;
    margin-bottom: 3px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 340px;
  }
  .data-value {
    font-size: 13px;
    font-weight: 600;
    color: #c4c4cc;
  }

  .new-badge {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 10px;
    color: #6366f1;
    background: rgba(99,102,241,0.12);
    border: 1px solid rgba(99,102,241,0.2);
    padding: 2px 7px;
    border-radius: 4px;
    letter-spacing: 0.06em;
  }

  /* 빈 상태 */
  .empty-state {
    padding: 48px 24px;
    text-align: center;
  }
  .empty-icon { font-size: 32px; margin-bottom: 12px; opacity: 0.4; }
  .empty-text { font-size: 13px; color: #52525b; line-height: 1.6; }

  /* 로딩 */
  .loading-state {
    padding: 48px 24px;
    text-align: center;
  }
  .spinner {
    width: 24px;
    height: 24px;
    border: 2px solid #1e1e2a;
    border-top-color: #6366f1;
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
    margin: 0 auto 12px;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .loading-text { font-family: 'IBM Plex Mono', monospace; font-size: 12px; color: #52525b; }
`;

function getStatusInfo(health) {
  if (health === '확인 중...') return { label: '확인 중...', cls: 'checking', dot: '' };
  if (health.includes('정상')) return { label: '정상 (Healthy)', cls: 'healthy', dot: 'healthy' };
  return { label: '연결 실패', cls: 'error', dot: 'error' };
}

export default function App() {
  const [dataList, setDataList] = useState([]);
  const [health, setHealth] = useState('확인 중...');
  const [loading, setLoading] = useState(false);

  const checkHealth = async () => {
    setHealth('확인 중...');
    try {
      const res = await fetch(`${API_BASE}/health`);
      setHealth(res.ok ? '✅ 정상 (Healthy)' : '❌ 경고 (Unhealthy)');
    } catch {
      setHealth('❌ 연결 실패 (서버 다운)');
    }
  };

  const fetchData = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/api/data`);
      const result = await res.json();
      if (result.status === 'success') setDataList(result.data);
    } catch (e) {
      console.error('데이터 가져오기 실패:', e);
    }
    setLoading(false);
  };

  const postData = async () => {
    try {
      await fetch(`${API_BASE}/api/data`, { method: 'POST' });
      fetchData();
    } catch (e) {
      console.error('데이터 전송 실패:', e);
    }
  };

  useEffect(() => {
    checkHealth();
    fetchData();
  }, []);

  const statusInfo = getStatusInfo(health);

  return (
    <>
      <style>{styles}</style>
      <div className="dashboard">
        <div className="container">

          {/* KT Cloud 배너 */}
          <div className="kt-banner">
            <div className="kt-banner-left">
              <div className="kt-logo">KT Cloud</div>
              <div className="kt-divider" />
              <div className="kt-course">클라우드 인프라 <span>2회차</span></div>
            </div>
            <div className="kt-team">Team 7 · 칠성파</div>
          </div>

          {/* 헤더 */}
          <header className="header">
            <div className="header-left">
              <div className="header-eyebrow">Infra Monitor</div>
              <h1 className="header-title">하이브리드 <span>인프라</span> 대시보드</h1>
              <div className="header-meta">
              </div>
            </div>
            <div className="live-badge">
              <div className={`live-dot ${statusInfo.dot}`} />
              LIVE
            </div>
          </header>

          {/* 서버 상태 카드 */}
          <div className="status-card">
            <div className="status-left">
              <div className="status-icon-wrap">🖥</div>
              <div className="status-info">
                <div className="status-label">Server Status</div>
                <div className={`status-value ${statusInfo.cls}`}>{statusInfo.label}</div>
              </div>
            </div>
            <button className="btn-ghost" onClick={checkHealth}>↺ 재확인</button>
          </div>

          {/* 액션 버튼 */}
          <div className="action-row">
            <button className="btn-primary" onClick={postData}>
              ＋ 데이터 1건 생성
            </button>
            <button className="btn-secondary" onClick={fetchData}>
              ↺ 새로고침
            </button>
          </div>

          {/* 데이터 패널 */}
          <div className="panel">
            <div className="panel-header">
              <div className="panel-title">
                📦 최근 DB 데이터
              </div>
              <span className="panel-count">{dataList.length} / 5</span>
            </div>

            {loading ? (
              <div className="loading-state">
                <div className="spinner" />
                <div className="loading-text">불러오는 중...</div>
              </div>
            ) : dataList.length > 0 ? (
              <ul className="data-list">
                {dataList.map((item, index) => (
                  <li key={item.id} className={`data-item ${index === 0 ? 'first' : ''}`}>
                    <span className="data-index">{index + 1}</span>
                    <div className="data-body">
                      <div className="data-id">{item.id}</div>
                      <div className="data-value">{item.value}</div>
                    </div>
                    {index === 0 && <span className="new-badge">NEW</span>}
                  </li>
                ))}
              </ul>
            ) : (
              <div className="empty-state">
                <div className="empty-icon">◻</div>
                <div className="empty-text">아직 데이터가 없습니다.<br />위 버튼으로 생성해보세요.</div>
              </div>
            )}
          </div>

        </div>
      </div>
    </>
  );
}