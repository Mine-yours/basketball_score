import React, { useState, useMemo, useEffect } from 'react';
import { Undo2, Clock, Flag, Trophy, AlertCircle } from 'lucide-react';

// ==========================================
// 1. 型定義とモックデータ
// ==========================================
type Team = 'home' | 'away';
type ActionType = '1P_MAKE' | '2P_MAKE' | '3P_MAKE' | 'MISS' | 'ASSIST' | 'OR' | 'DR' | 'STEAL' | 'BLOCK' | 'TO' | 'FOUL';

interface Player {
    id: string;
    number: string;
    name: string;
    team: Team;
    isTeam?: boolean; // チーム全体（個人不明）の場合のフラグ
}

interface GameEvent {
    id: string;
    timestamp: number;
    team: Team;
    playerId: string;
    action: ActionType;
    x?: number;
    y?: number;
    assistPlayerId?: string; // アシストを付帯情報として保持
}

const PLAYERS: Player[] = [
    // Home Team
    { id: 'h1', number: '4', name: '田中 誠', team: 'home' },
    { id: 'h2', number: '5', name: '鈴木 健太', team: 'home' },
    { id: 'h3', number: '6', name: '佐藤 大輔', team: 'home' },
    { id: 'h4', number: '7', name: '高橋 涼', team: 'home' },
    { id: 'h5', number: '8', name: '伊藤 翔', team: 'home' },
    { id: 'h_team', number: '-', name: 'Home Team', team: 'home', isTeam: true }, // 不明時用
    // Away Team
    { id: 'a1', number: '4', name: 'John Smith', team: 'away' },
    { id: 'a2', number: '5', name: 'David Doe', team: 'away' },
    { id: 'a3', number: '6', name: 'Mike Johnson', team: 'away' },
    { id: 'a4', number: '7', name: 'Chris Lee', team: 'away' },
    { id: 'a5', number: '8', name: 'James Brown', team: 'away' },
    { id: 'a_team', number: '-', name: 'Away Team', team: 'away', isTeam: true }, // 不明時用
];

const ACTION_LABELS: Record<ActionType | 'REB', string> = {
    '1P_MAKE': '+1 (FT)',
    '2P_MAKE': '+2 得点',
    '3P_MAKE': '+3 得点',
    'MISS': 'シュートミス',
    'ASSIST': 'アシスト',
    'OR': 'O.リバウンド',
    'DR': 'D.リバウンド',
    'STEAL': 'スティール',
    'BLOCK': 'ブロック',
    'TO': 'ターンオーバー',
    'FOUL': 'ファウル',
    'REB': 'リバウンド', // 表示用仮想アクション
};

// ==========================================
// 2. メインアプリケーションコンポーネント
// ==========================================
export default function App() {
    // --- 永続化ステート ---
    const [events, setEvents] = useState<GameEvent[]>([]);

    // --- 順不同入力用ペンディングステート ---
    const [pendingPlayer, setPendingPlayer] = useState<Player | null>(null);
    const [pendingAction, setPendingAction] = useState<ActionType | 'REB' | null>(null);
    const [pendingShotPos, setPendingShotPos] = useState<{ x: number, y: number } | null>(null);

    // シュート入力用の2段階モーダルステート (1: 結果, 2: アシスト)
    const [shotModalStep, setShotModalStep] = useState<1 | 2 | null>(null);
    const [animState, setAnimState] = useState<{ key: number, text: string, team?: Team } | null>(null);

    // --- Computed Properties (算出ロジック) ---
    const { homeScore, awayScore, homeFouls, awayFouls, recentEvents } = useMemo(() => {
        let hs = 0, as = 0, hf = 0, af = 0;

        events.forEach(e => {
            const pts = e.action === '1P_MAKE' ? 1 : e.action === '2P_MAKE' ? 2 : e.action === '3P_MAKE' ? 3 : 0;
            if (e.team === 'home') {
                hs += pts;
                if (e.action === 'FOUL') hf += 1;
            } else {
                as += pts;
                if (e.action === 'FOUL') af += 1;
            }
        });

        return {
            homeScore: hs,
            awayScore: as,
            homeFouls: hf,
            awayFouls: af,
            recentEvents: [...events].reverse().slice(0, 3) // ヘッダーに収まるよう直近3件に変更
        };
    }, [events]);

    // --- Helper: 3P自動判定ロジック ---
    // リングからの距離と角度で判定
    const is3Pointer = (x: number, y: number) => {
        const isLeftCourt = x < 400;
        // 直線部分 (コーナー) の判定
        if (isLeftCourt) {
            if (x < 120 && (y < 60 || y > 340)) return true;
        } else {
            if (x > 680 && (y < 60 || y > 340)) return true;
        }
        // 円弧部分の判定 (リング中心からおよそ180px以上離れていれば3P)
        const arcCenterX = isLeftCourt ? 7 : 793;
        const distance = Math.sqrt(Math.pow(x - arcCenterX, 2) + Math.pow(y - 200, 2));
        return distance >= 180;
    };

    // --- 状態リセット ---
    const clearPending = () => {
        setPendingPlayer(null);
        setPendingAction(null);
        setPendingShotPos(null);
        setShotModalStep(null);
    };

    const triggerAnimation = (text: string, team?: Team) => {
        setAnimState(prev => ({ key: (prev?.key || 0) + 1, text, team }));
    };

    // --- アクションの記録処理 (共通) ---
    const processGeneralAction = (player: Player, act: ActionType | 'REB') => {
        let finalAction = act as ActionType;

        // リバウンドの自動判定 (OR / DR)
        if (act === 'REB') {
            const lastEvent = events[events.length - 1];
            if (lastEvent && lastEvent.action === 'MISS') {
                finalAction = lastEvent.team === player.team ? 'OR' : 'DR';
            } else {
                // 直前がミスでない場合のフォールバック（直前のイベントチームと同じならORとする）
                finalAction = (lastEvent && lastEvent.team === player.team) ? 'OR' : 'DR';
            }
        }

        const newEvent: GameEvent = {
            id: crypto.randomUUID(),
            timestamp: Date.now(),
            team: player.team,
            playerId: player.id,
            action: finalAction
        };

        setEvents(prev => [...prev, newEvent]);
        triggerAnimation(`${player.name} : ${ACTION_LABELS[finalAction]}`, player.team);
    };

    // --- イベントハンドラ: プレイヤー選択 ---
    const handlePlayerSelect = (p: Player) => {
        if (pendingAction) {
            // 既にアクションが選択されていた場合、条件が揃ったので記録
            processGeneralAction(p, pendingAction);
            clearPending();
        } else if (pendingShotPos) {
            // 既にシュート位置が選択されていた場合、シュートモーダルへ
            setPendingPlayer(p);
            setShotModalStep(1);
        } else {
            // 何もない場合はペンディング状態をトグル
            setPendingPlayer(prev => prev?.id === p.id ? null : p);
        }
    };

    // --- イベントハンドラ: アクション選択 ---
    const handleActionSelect = (act: ActionType | 'REB') => {
        if (pendingPlayer) {
            // 既にプレイヤーが選択されていた場合、条件が揃ったので記録
            processGeneralAction(pendingPlayer, act);
            clearPending();
        } else if (pendingShotPos) {
            // 位置が選択されていたが、シュート以外のアクションを押した場合（変更）
            setPendingShotPos(null);
            setPendingAction(act);
        } else {
            setPendingAction(prev => prev === act ? null : act);
        }
    };

    // --- イベントハンドラ: コートタップ (位置入力) ---
    const handleCourtClick = (e: React.MouseEvent<SVGSVGElement>) => {
        const rect = e.currentTarget.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width) * 800;
        const y = ((e.clientY - rect.top) / rect.height) * 400;

        if (pendingPlayer) {
            // プレイヤーが選択済みなら即座にシュートモーダルへ
            setPendingShotPos({ x, y });
            setShotModalStep(1);
        } else {
            setPendingShotPos({ x, y });
        }
    };

    // --- イベントハンドラ: シュート結果の最終処理 ---
    const handleShotResult = (result: 'MAKE' | 'MISS', assistId?: string) => {
        if (!pendingPlayer || !pendingShotPos) return;

        let action: ActionType = 'MISS';
        if (result === 'MAKE') {
            action = is3Pointer(pendingShotPos.x, pendingShotPos.y) ? '3P_MAKE' : '2P_MAKE';
        }

        const newEvent: GameEvent = {
            id: crypto.randomUUID(),
            timestamp: Date.now(),
            team: pendingPlayer.team,
            playerId: pendingPlayer.id,
            action,
            x: pendingShotPos.x,
            y: pendingShotPos.y,
            assistPlayerId: assistId
        };

        setEvents(prev => [...prev, newEvent]);
        triggerAnimation(`${pendingPlayer.name} : ${ACTION_LABELS[action]}`, pendingPlayer.team);
        clearPending();
    };

    const handleUndo = () => {
        if (events.length === 0) return;
        setEvents(prev => prev.slice(0, -1));
        triggerAnimation('↩️ 取り消しました');
    };

    // ==========================================
    // 3. UI レンダリング
    // ==========================================
    return (
        <div className="h-screen w-full bg-slate-950 text-slate-50 flex flex-col font-sans overflow-hidden select-none">

            {/* --- カスタムCSS (アニメーション用) --- */}
            <style>{`
        @keyframes popupGlow {
          0% { opacity: 0; transform: translateY(20px) scale(0.9); }
          15% { opacity: 1; transform: translateY(0) scale(1.1); }
          85% { opacity: 1; transform: translateY(0) scale(1); }
          100% { opacity: 0; transform: translateY(-20px) scale(0.9); }
        }
        .animate-popup { animation: popupGlow 1.8s cubic-bezier(0.16, 1, 0.3, 1) forwards; }
        @keyframes slideUpFade {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-modal { animation: slideUpFade 0.2s ease-out forwards; }
      `}</style>

            {/* --- ヘッダー領域 --- */}
            <header className="flex justify-between items-center px-6 py-2 bg-slate-900 border-b border-slate-800 shadow-md z-20 h-24">
                <div className="flex items-center space-x-6 w-[30%]">
                    <div className="text-center">
                        <span className="text-slate-400 text-sm font-bold tracking-widest uppercase">Home</span>
                        <div className="text-5xl font-black text-blue-400 leading-none">{homeScore}</div>
                    </div>
                    <div className="flex flex-col justify-center">
                        <div className="flex items-center text-red-400/80 mb-1">
                            <Flag size={16} className="mr-1" />
                            <span className="text-sm font-bold">Fouls: {homeFouls}</span>
                        </div>
                        <div className="flex space-x-1">
                            {[...Array(5)].map((_, i) => (
                                <div key={i} className={`w-3 h-3 rounded-full ${i < homeFouls ? 'bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.8)]' : 'bg-slate-700'}`} />
                            ))}
                        </div>
                    </div>
                </div>

                <div className="flex items-center justify-center w-[40%] h-full gap-4">
                    <div className="flex flex-col items-center justify-center shrink-0">
                        <div className="text-slate-400 font-bold tracking-widest text-sm mb-1">Q2</div>
                        <div className="flex items-center text-4xl font-black tracking-wider text-amber-400 font-mono">
                            <Clock className="mr-3 text-amber-500" size={32} />
                            08:24
                        </div>
                    </div>

                    <div className="h-4/5 w-[1px] bg-slate-700 mx-2"></div>

                    <div className="flex-1 flex flex-col justify-center h-full overflow-hidden max-w-xs">
                        <h3 className="text-[10px] text-slate-400 font-bold mb-1 uppercase flex items-center"><ActivityIcon /> <span className="ml-1">Recent Plays</span></h3>
                        <div className="flex flex-col space-y-1 overflow-hidden">
                            {recentEvents.length === 0 ? <p className="text-slate-500 text-[10px]">記録なし</p> : null}
                            {recentEvents.map(ev => {
                                const p = PLAYERS.find(p => p.id === ev.playerId);
                                const astP = ev.assistPlayerId ? PLAYERS.find(p => p.id === ev.assistPlayerId) : null;
                                return (
                                    <div key={ev.id} className="flex flex-col text-[10px] leading-tight">
                                        <div className="flex justify-between items-center">
                                            <span className={`font-bold truncate max-w-[120px] ${ev.team === 'home' ? 'text-blue-400' : 'text-red-400'}`}>
                                                {p?.number !== '-' ? `#${p?.number} ` : ''}{p?.name}
                                            </span>
                                            <span className="font-medium text-slate-300">
                                                {ACTION_LABELS[ev.action].replace(' 得点', '')}
                                            </span>
                                        </div>
                                        {astP && (
                                            <span className="text-slate-500 text-[9px] ml-2">↳ Ast: {astP.name}</span>
                                        )}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>

                <div className="flex items-center space-x-6 w-[30%] justify-end">
                    <div className="flex flex-col justify-center items-end">
                        <div className="flex items-center text-red-400/80 mb-1">
                            <span className="text-sm font-bold mr-1">Fouls: {awayFouls}</span>
                            <Flag size={16} />
                        </div>
                        <div className="flex space-x-1">
                            {[...Array(5)].map((_, i) => (
                                <div key={i} className={`w-3 h-3 rounded-full ${i < awayFouls ? 'bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.8)]' : 'bg-slate-700'}`} />
                            ))}
                        </div>
                    </div>
                    <div className="text-center">
                        <span className="text-slate-400 text-sm font-bold tracking-widest uppercase">Away</span>
                        <div className="text-5xl font-black text-red-400 leading-none">{awayScore}</div>
                    </div>
                </div>
            </header>

            {/* --- メインコンテンツ領域 --- */}
            <main className="flex-1 flex overflow-hidden relative">

                {/* SVG アニメーションオーバーレイ */}
                {animState && (
                    <div key={animState.key} className="absolute inset-0 pointer-events-none flex items-center justify-center z-50 animate-popup">
                        <svg width="500" height="160" viewBox="0 0 500 160">
                            <defs>
                                <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
                                    <feGaussianBlur stdDeviation="8" result="blur" />
                                    <feComposite in="SourceGraphic" in2="blur" operator="over" />
                                </filter>
                            </defs>
                            <rect x="25" y="30" width="450" height="100" rx="20" fill="#0f172a" fillOpacity="0.85"
                                stroke={animState.team === 'home' ? '#3b82f6' : animState.team === 'away' ? '#ef4444' : '#64748b'}
                                strokeWidth="4" filter="url(#glow)" />
                            <text x="250" y="85" fontFamily="sans-serif" fontSize="28" fontWeight="bold" fill="#ffffff" textAnchor="middle" dominantBaseline="middle">
                                {animState.text}
                            </text>
                        </svg>
                    </div>
                )}

                {/* --- 左サイド: Home Players --- */}
                <div className="w-1/4 max-w-[240px] h-full overflow-y-auto p-4 border-r border-slate-800/50 z-10 bg-slate-950/40 backdrop-blur-sm">
                    <h2 className="text-blue-400 font-bold mb-4 text-center tracking-widest">HOME TEAM</h2>
                    {PLAYERS.filter(p => p.team === 'home').map(player => {
                        const isSelected = pendingPlayer?.id === player.id;
                        return (
                            <button
                                key={player.id}
                                onClick={() => handlePlayerSelect(player)}
                                className={`w-full flex items-center p-3 mb-2 rounded-xl border-2 transition-all duration-200 transform active:scale-95
                  ${isSelected
                                        ? 'bg-blue-600 border-blue-400 shadow-[0_0_15px_rgba(59,130,246,0.6)]'
                                        : player.isTeam
                                            ? 'bg-slate-800/80 border-slate-600 hover:bg-slate-700 hover:border-slate-400 border-dashed'
                                            : 'bg-slate-900/60 border-slate-800 hover:bg-slate-800 hover:border-slate-600'}`}
                            >
                                <span className={`text-xl font-black w-10 text-center ${player.isTeam ? 'text-slate-400' : ''}`}>{player.number}</span>
                                <span className="text-md font-bold flex-1 text-left ml-2 truncate">{player.name}</span>
                            </button>
                        );
                    })}
                </div>

                {/* --- センター領域: コートとアクションパッド --- */}
                <div className="flex-1 flex flex-col p-4 z-10 relative h-full">

                    {/* インタラクティブ・ショットチャート (コート) */}
                    <div className="w-full aspect-[2/1] max-h-[60%] bg-slate-900/40 rounded-2xl border-2 border-slate-700 relative overflow-hidden flex-shrink-0 shadow-inner">
                        <svg
                            viewBox="0 0 800 400"
                            className="absolute inset-0 w-full h-full cursor-crosshair"
                            preserveAspectRatio="none"
                            onClick={handleCourtClick}
                        >
                            <g stroke="#475569" strokeWidth="4" fill="none">
                                <rect x="20" y="20" width="760" height="360" />
                                <line x1="400" y1="20" x2="400" y2="380" />
                                <circle cx="400" cy="200" r="60" />
                                {/* 3PT Lines */}
                                <path d="M 20 60 L 120 60 A 180 180 0 0 1 120 340 L 20 340" />
                                <path d="M 780 60 L 680 60 A 180 180 0 0 0 680 340 L 780 340" />
                                {/* Keys */}
                                <rect x="20" y="120" width="140" height="160" />
                                <rect x="640" y="120" width="140" height="160" />
                                {/* Rings */}
                                <circle cx="45" cy="200" r="8" stroke="#ef4444" strokeWidth="3" />
                                <circle cx="755" cy="200" r="8" stroke="#ef4444" strokeWidth="3" />
                            </g>

                            {/* プロット */}
                            {events.map(ev => {
                                if (ev.x === undefined || ev.y === undefined) return null;
                                const isMake = ev.action.includes('MAKE');
                                const teamColor = ev.team === 'home' ? '#3b82f6' : '#ef4444';

                                if (isMake) {
                                    return <circle key={ev.id} cx={ev.x} cy={ev.y} r="8" fill={teamColor} stroke="#fff" strokeWidth="2" />;
                                } else {
                                    return (
                                        <g key={ev.id} stroke={teamColor} strokeWidth="3" opacity="0.8">
                                            <line x1={ev.x - 6} y1={ev.y - 6} x2={ev.x + 6} y2={ev.y + 6} />
                                            <line x1={ev.x - 6} y1={ev.y + 6} x2={ev.x + 6} y2={ev.y - 6} />
                                        </g>
                                    );
                                }
                            })}

                            {/* ペンディング中のタップ位置マーカー */}
                            {pendingShotPos && (
                                <circle cx={pendingShotPos.x} cy={pendingShotPos.y} r="14" fill="#fbbf24" stroke="#fff" strokeWidth="4" className="animate-pulse" />
                            )}
                        </svg>
                    </div>

                    {/* その他のアクションパッド (下部) */}
                    <div className="flex-1 mt-4 flex flex-col justify-end w-full max-w-2xl mx-auto">
                        <div className="grid grid-cols-4 gap-2 mb-2">
                            <ActionButton label="FT (+1)" color="bg-emerald-600 border-emerald-400" isActive={pendingAction === '1P_MAKE'} onClick={() => handleActionSelect('1P_MAKE')} size="sm" />
                            <ActionButton label="リバウンド" color="bg-indigo-600 border-indigo-400" isActive={pendingAction === 'REB'} onClick={() => handleActionSelect('REB')} size="sm" />
                            <ActionButton label="スティール" color="bg-purple-600 border-purple-400" isActive={pendingAction === 'STEAL'} onClick={() => handleActionSelect('STEAL')} size="sm" />
                            <ActionButton label="ブロック" color="bg-purple-600 border-purple-400" isActive={pendingAction === 'BLOCK'} onClick={() => handleActionSelect('BLOCK')} size="sm" />
                        </div>
                        <div className="grid grid-cols-4 gap-2 mb-4">
                            <ActionButton label="ターンオーバー" color="bg-rose-700 border-rose-500" isActive={pendingAction === 'TO'} onClick={() => handleActionSelect('TO')} size="sm" className="col-span-2" />
                            <ActionButton label="ファウル" color="bg-red-600 border-red-400 shadow-[0_0_10px_rgba(239,68,68,0.2)]" isActive={pendingAction === 'FOUL'} onClick={() => handleActionSelect('FOUL')} size="sm" className="col-span-2" />
                        </div>

                        {/* Undo / Cancel */}
                        <div className="flex gap-2">
                            {(pendingPlayer || pendingAction || pendingShotPos) && (
                                <button
                                    onClick={clearPending}
                                    className="flex-1 py-3 rounded-xl text-md font-bold transition-all border-2 bg-slate-800 border-slate-600 text-slate-300 hover:bg-slate-700 active:scale-95"
                                >
                                    選択キャンセル
                                </button>
                            )}
                            <button
                                onClick={handleUndo}
                                disabled={events.length === 0}
                                className={`flex-1 py-3 rounded-xl text-lg font-bold flex items-center justify-center transition-all border-2
                  ${events.length === 0
                                        ? 'bg-slate-800 border-slate-700 text-slate-500 cursor-not-allowed'
                                        : 'bg-slate-700 border-slate-500 text-white hover:bg-slate-600 active:scale-95 shadow-md'}`}
                            >
                                <Undo2 className="mr-2" size={24} />
                                1つ戻る (Undo)
                            </button>
                        </div>
                    </div>
                </div>

                {/* --- 右サイド: Away Players --- */}
                <div className="w-1/4 max-w-[240px] h-full overflow-y-auto p-4 border-l border-slate-800/50 z-10 bg-slate-950/40 backdrop-blur-sm">
                    <h2 className="text-red-400 font-bold mb-4 text-center tracking-widest">AWAY TEAM</h2>
                    {PLAYERS.filter(p => p.team === 'away').map(player => {
                        const isSelected = pendingPlayer?.id === player.id;
                        return (
                            <button
                                key={player.id}
                                onClick={() => handlePlayerSelect(player)}
                                className={`w-full flex items-center justify-between p-3 mb-2 rounded-xl border-2 transition-all duration-200 transform active:scale-95
                  ${isSelected
                                        ? 'bg-red-600 border-red-400 shadow-[0_0_15px_rgba(239,68,68,0.6)]'
                                        : player.isTeam
                                            ? 'bg-slate-800/80 border-slate-600 hover:bg-slate-700 hover:border-slate-400 border-dashed'
                                            : 'bg-slate-900/60 border-slate-800 hover:bg-slate-800 hover:border-slate-600'}`}
                            >
                                <span className="text-md font-bold flex-1 text-right mr-2 truncate">{player.name}</span>
                                <span className={`text-xl font-black w-10 text-center ${player.isTeam ? 'text-slate-400' : ''}`}>{player.number}</span>
                            </button>
                        );
                    })}
                </div>

            </main>

            {/* --- シュート結果 2段階モーダル --- */}
            {shotModalStep && pendingPlayer && pendingShotPos && (
                <div className="absolute inset-0 z-[100] flex items-center justify-center bg-slate-950/80 backdrop-blur-sm animate-modal">
                    <div className="bg-slate-900 border-2 border-slate-700 p-6 rounded-2xl shadow-2xl max-w-lg w-full mx-4 relative overflow-hidden">

                        {/* Step 1: Make or Miss */}
                        {shotModalStep === 1 && (
                            <div className="animate-modal">
                                <h3 className="text-xl font-bold mb-2 text-center text-slate-200">
                                    <span className={pendingPlayer.team === 'home' ? 'text-blue-400' : 'text-red-400'}>
                                        {pendingPlayer.number !== '-' ? `#${pendingPlayer.number} ` : ''}{pendingPlayer.name}
                                    </span> のシュート
                                </h3>
                                <p className="text-center text-slate-400 text-sm mb-6">
                                    判定: <strong className="text-amber-400">{is3Pointer(pendingShotPos.x, pendingShotPos.y) ? '3 Point Area' : '2 Point Area'}</strong>
                                </p>

                                <div className="grid grid-cols-2 gap-4 mb-6">
                                    <button
                                        className="py-8 rounded-2xl font-black text-3xl bg-emerald-600 hover:bg-emerald-500 border-b-[6px] border-emerald-800 active:translate-y-2 active:border-b-0 transition-all text-white shadow-xl"
                                        onClick={() => setShotModalStep(2)} // 成功ならステップ2へ
                                    >
                                        成功 (Make)
                                    </button>
                                    <button
                                        className="py-8 rounded-2xl font-black text-3xl bg-orange-600 hover:bg-orange-500 border-b-[6px] border-orange-800 active:translate-y-2 active:border-b-0 transition-all text-white shadow-xl"
                                        onClick={() => handleShotResult('MISS')} // ミスなら確定して閉じる
                                    >
                                        ミス (Miss)
                                    </button>
                                </div>
                            </div>
                        )}

                        {/* Step 2: Assist Selection */}
                        {shotModalStep === 2 && (
                            <div className="animate-modal">
                                <h3 className="text-xl font-bold mb-6 text-center text-emerald-400">
                                    シュート成功！ アシストはありましたか？
                                </h3>

                                <div className="flex flex-col gap-3 mb-6">
                                    <button
                                        className="w-full py-4 bg-slate-700 hover:bg-slate-600 border-2 border-slate-500 rounded-xl font-bold text-white text-lg transition-all active:scale-95"
                                        onClick={() => handleShotResult('MAKE')}
                                    >
                                        アシストなし (Unassisted)
                                    </button>

                                    <div className="h-[1px] bg-slate-800 my-2 w-full"></div>

                                    <div className="grid grid-cols-2 gap-3">
                                        {PLAYERS.filter(p => p.team === pendingPlayer.team && p.id !== pendingPlayer.id).map(p => (
                                            <button
                                                key={p.id}
                                                className={`py-3 rounded-xl font-bold transition-all active:scale-95 border-2
                          ${p.isTeam ? 'bg-slate-800 border-slate-600 text-slate-300 border-dashed' : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'}`}
                                                onClick={() => handleShotResult('MAKE', p.id)}
                                            >
                                                {p.number !== '-' ? `#${p.number} ` : ''}{p.name}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        )}

                        <button
                            className="w-full py-3 bg-transparent hover:bg-slate-800 rounded-xl font-bold text-slate-400 transition-colors"
                            onClick={clearPending}
                        >
                            キャンセル
                        </button>
                    </div>
                </div>
            )}

        </div>
    );
}

// --- ユーティリティコンポーネント ---
function ActionButton({ label, color, onClick, isActive, size = 'lg', className = '' }:
    { label: string, color: string, onClick: () => void, isActive?: boolean, size?: 'sm' | 'lg', className?: string }) {

    const padding = size === 'sm' ? 'py-4 px-2' : 'py-6 px-2';
    const text = size === 'sm' ? 'text-base' : 'text-lg';

    // ペンディング（選択中）状態のスタイリング
    const activeStyle = isActive
        ? 'ring-4 ring-white ring-offset-2 ring-offset-slate-950 transform scale-[0.98] border-b-0 translate-y-1 brightness-125'
        : 'border-b-4 hover:brightness-110 active:translate-y-1 active:border-b-0';

    return (
        <button
            onClick={onClick}
            className={`${padding} rounded-2xl font-black ${text} shadow-lg transition-all ${color} ${activeStyle} ${className}`}
        >
            {label}
        </button>
    );
}

function ActivityIcon() {
    return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
        </svg>
    );
}