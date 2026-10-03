/* Startup-only diagnostics. No telemetry or gameplay listeners survive completion. */
window.createGodotBaseLoadingDetails = function ({ language, stageNames, fail }) {
    const ko = language === 'ko';
    const labels = {
        audio_catalog: ['효과음 목록 불러오기', 'Collecting sound resources'],
        audio: ['브라우저 오디오 준비', 'Preparing browser audio'],
        hud_font: ['HUD 글꼴 준비', 'Preparing HUD text'],
        damage_font: ['피해 숫자 글꼴 준비', 'Preparing damage text'],
        combat_effects: ['폭발·피격 효과 준비', 'Preparing combat effects'],
        ranged_effects: ['투사체 효과 준비', 'Preparing projectile effects'],
        status_effects: ['상태 이상 효과 준비', 'Preparing status effects'],
        world_materials: ['환경 재질 준비', 'Preparing world materials'],
        player_materials: ['캐릭터 재질 준비', 'Preparing player materials'],
        weapon_effects: ['무기·화염 효과 준비', 'Preparing weapon effects'],
        prop_fragments: ['소품 파편 불러오기', 'Loading prop fragments'],
        enemy_fragments: ['크리처 파편 불러오기', 'Loading creature fragments'],
        fragment_materials: ['파편 재질 준비', 'Preparing fragment materials'],
        ui_effects: ['화면 효과 준비', 'Preparing interface effects'],
        light_states: ['셰이더 준비', 'Preparing shaders'],
    };
    const get = id => document.getElementById(id);
    const panel = get('loading-details'), task = get('loading-task'), item = get('loading-item');
    const count = get('loading-count'), bar = get('loading-task-progress');
    const times = get('loading-times'), stalled = get('loading-stalled'), log = get('loading-log');
    const copy = get('loading-copy');
    const canvas = get('canvas');
    const graphics = window.createGodotBaseLoadingGraphics(canvas);
    const graphicsText = get('loading-graphics');
    const ua = navigator.userAgent || '';
    const browserMatch = ua.match(/(CriOS|FxiOS|Edg|Chrome|Firefox)\/([\d.]+)/) || ua.match(/Version\/([\d.]+).*?(Safari)/);
    const browser = browserMatch ? (browserMatch[2] === 'Safari' ? 'Safari ' + browserMatch[1]
        : browserMatch[1] + ' ' + browserMatch[2]) : (ua.slice(0, 64) || 'Browser unknown');
    const storageKey = ((window.GodotBaseConfig || {}).projectId || 'my-game') + '.startup-failure';
    let previousFailure = '';
    try { previousFailure = localStorage.getItem(storageKey) || ''; } catch (_) {}
    let failureDetails = '';
    get('loading-log-title').textContent = ko ? '상세 기록' : 'Details';
    copy.textContent = ko ? '진단 기록 복사' : 'Copy diagnostics';
    const start = performance.now();
    let taskStart = start, lastChange = start, signature = '', phase = '', live = true, failed = false;
    let pending = ko ? '브라우저 준비' : 'Browser startup';
    const history = [];
    const environment = ['build=' + ((window.GodotBaseConfig || {}).build || 'DEV'),
        navigator.userAgent || 'Browser information unavailable'];
    const seconds = time => Math.max(0, time / 1000).toFixed(1);
    const record = text => {
        history.push(`[${seconds(performance.now() - start)}s] ${String(text).slice(0, 1200)}`);
        if (history.length > 256) history.shift();
    };
    function refresh() {
        if (!live) return;
        const now = performance.now(), idle = now - lastChange;
        times.textContent = ko
            ? `총 ${seconds(now - start)}초 · 현재 작업 ${seconds(now - taskStart)}초 · 최근 갱신 ${seconds(idle)}초 전`
            : `Total ${seconds(now - start)}s · Task ${seconds(now - taskStart)}s · Updated ${seconds(idle)}s ago`;
        stalled.hidden = idle < 20000;
        stalled.textContent = ko
            ? `현재 작업의 완료 응답을 기다리고 있습니다. ${seconds(idle)}초 동안 진행 갱신이 없습니다. 조금 더 기다리거나 상세 기록을 복사해 주세요.`
            : `Waiting for this task to finish. No progress update for ${seconds(idle)}s. You can keep waiting or copy the details.`;
        panel.dataset.stalled = String(!stalled.hidden);
        const gpu = graphics.snapshot(), slow = gpu.slowest;
        const compactPath = value => String(value || '').split('|').map(path => path.split('/').pop()).join(', ');
        const lines = [browser + ' · ' + (gpu.platform || 'unknown') + ' · ' + (ko ? '터치 ' : 'Touch ') + gpu.touch_points,
            `${ko ? '화면' : 'View'} ${gpu.canvas_css_px.join('×')} @${gpu.dpr} · ${ko ? '버퍼' : 'Buffer'} ${gpu.canvas_px.join('×')}`];
        if (slow) {
            lines.push(`${ko ? 'WebGL 최장 호출(CPU)' : 'Longest WebGL call (CPU)'}: ${slow.duration_ms}ms · ${slow.method}`);
            if (slow.shader) lines.push((ko ? '해당 셰이더: ' : 'Shader: ') + compactPath(slow.shader));
        }
        graphicsText.textContent = lines.join('\n');
        log.textContent = environment.join('\n') + `\nPending: ${pending}\n${times.textContent}\n` + history.join('\n')
            + failureDetails + (previousFailure ? '\nPrevious startup failure:\n' + previousFailure.slice(0, 40000) : '');
    }
    function change(key, name) {
        if (phase !== key) { phase = key; taskStart = performance.now(); }
        if (signature !== name) { signature = name; lastChange = performance.now(); record(name); }
        pending = name;
        refresh();
    }
    const timer = setInterval(refresh, 500);
    const onError = event => fail(event.message || 'Browser startup error');
    const onRejection = event => fail(event.reason instanceof Error ? event.reason : String(event.reason));
    const onContextLost = event => {
        // The page owns startup failure UI. Avoid Godot's blocking alert so the
        // diagnostic copy/reload controls remain usable even without the engine.
        event?.preventDefault();
        event?.stopImmediatePropagation();
        record('CONTEXT_LOST status=' + String(event?.statusMessage || '(not supplied)').slice(0, 512));
        fail(ko ? '그래픽 연결이 끊겼습니다 (WebGL context lost).' : 'WebGL context lost.');
    };
    window.addEventListener('error', onError);
    window.addEventListener('unhandledrejection', onRejection);
    canvas.addEventListener('webglcontextlost', onContextLost, true);
    copy.addEventListener('click', async () => {
        refresh();
        try {
            await navigator.clipboard.writeText(log.textContent);
            copy.textContent = ko ? '복사 완료' : 'Copied';
        } catch (_) {
            get('loading-history').open = true;
            copy.textContent = ko ? '아래 기록을 선택해 복사해 주세요' : 'Select and copy the details below';
        }
    });
    refresh();
    return {
        download(current, total) {
            if (!live) return;
            const mib = value => (Math.max(0, value) / 1048576).toFixed(1) + ' MiB';
            task.textContent = stageNames[2];
            count.textContent = '';
            item.textContent = mib(current) + (total > 0 ? ' / ' + mib(total) : '');
            bar.hidden = true;
            change('data', `${stageNames[2]} ${current}/${total}`);
        },
        stage(name, ratio, completed, total) {
            if (!live) return;
            // Fine-grained graphics reports own the task clock once received.
            if (name === 'graphics' && labels[phase]) return;
            const index = ['browser','engine','data','runtime','resources','scene','systems','graphics','frame'].indexOf(name);
            const label = stageNames[index] || name;
            task.textContent = label;
            item.textContent = '';
            count.textContent = total > 0 ? `${completed} / ${total}` : '';
            bar.hidden = total <= 0;
            if (total > 0) { bar.max = total; bar.value = completed; }
            change(name, `${label} ${total > 0 ? completed + '/' + total : Math.round(ratio * 100) + '%'}`);
        },
        report(payload) {
            if (!live) return;
            let data;
            try { data = typeof payload === 'string' ? JSON.parse(payload) : payload; } catch (_) { return; }
            if (!data || !labels[data.phase] || !Number.isFinite(data.completed) || !Number.isFinite(data.total)) return;
            const label = labels[data.phase][ko ? 0 : 1];
            task.textContent = `${data.phase_index}/${data.phase_total} · ${label}`;
            let resource = String(data.item || '');
            if (resource.startsWith('lights ')) {
                const [lights, batch] = resource.slice(7).split(' | ');
                const values = lights.split('/');
                const names = ko ? ['섬광', '손전등', '실내등'] : ['Flash', 'Flashlight', 'Room light'];
                resource = names.map((name, i) => `${name} ${values[i] === '1' ? 'ON' : 'OFF'}`).join(' · ');
                if (batch) {
                    const [number, paths] = batch.split(': ');
                    const names = (paths || '').split(', ').map(path => path.split('/').slice(-2).join('/'));
                    resource += '\n' + number.replace('batch ', ko ? '재질 묶음 ' : 'Batch ')
                        + (names.length ? ' · ' + names[0] + (names.length > 1 ? ' … ' + names.at(-1) : '') : '');
                }
            } else if (resource === 'scene') resource = ko ? '원래 장면·조명 복원' : 'Restoring scene lighting';
            if (data.phase !== 'audio' && data.audio_total > data.audio_completed) {
                resource += (resource ? '\n' : '') + (ko ? '사운드 함께 준비 중 ' : 'Preparing audio alongside ') + `${data.audio_completed}/${data.audio_total}`;
            }
            item.textContent = resource;
            count.textContent = data.total > 0 ? (data.phase === 'light_states'
                ? Math.floor(data.completed / data.total * 100) + '%' : `${data.completed} / ${data.total}`) : (ko ? '추가 준비 없음' : 'Already prepared');
            bar.hidden = data.total <= 0;
            if (data.total > 0) { bar.max = data.total; bar.value = data.completed; }
            change(data.phase, `${label} ${data.completed}/${data.total} · ${String(data.item || resource)}`);
        },
        engineError(message) {
            if (!live) return;
            const text = String(message).slice(0, 1200);
            record('ENGINE: ' + text);
            refresh();
            if (/SCRIPT ERROR|Parse Error|out of memory|memory access out of bounds/i.test(text)) fail(text);
        },
        failure(message) {
            if (!live || failed) return;
            failed = true;
            get('status-panel').dataset.failed = 'true';
            record('FAILED: ' + String(message));
            failureDetails = '\nGraphics: ' + JSON.stringify(graphics.snapshot());
            refresh();
            // One bounded local record survives reload; nothing is sent automatically.
            const current = (environment.join('\n') + `\nPending: ${pending}\n${times.textContent}\n` + history.slice(-16).join('\n') + failureDetails).slice(0, 40000);
            try { localStorage.setItem(storageKey, current); } catch (_) {}
            panel.hidden = false;
            get('loading-history').open = true;
        },
        stop() {
            live = false;
            clearInterval(timer);
            window.removeEventListener('error', onError);
            window.removeEventListener('unhandledrejection', onRejection);
            canvas.removeEventListener('webglcontextlost', onContextLost, true);
            graphics.stop();
        },
    };
};
