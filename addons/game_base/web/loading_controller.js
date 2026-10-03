(function () {
	const config = window.GodotBaseConfig || {};
	const statusOverlay = document.getElementById('status');
	const statusProgress = document.getElementById('status-progress');
	const statusNotice = document.getElementById('status-notice');
	let savedLanguage = null;
	try { savedLanguage = localStorage.getItem((config.projectId || 'my-game') + '.language'); } catch (error) {}
	const primaryLanguage = (navigator.languages && navigator.languages[0]) || navigator.language || 'en';
	const language = ['en', 'ko'].includes(savedLanguage) ? savedLanguage
		: (primaryLanguage.trim().toLowerCase().split(/[-_]/)[0] === 'ko' ? 'ko' : 'en');
	document.documentElement.lang = language;
	const messages = language === 'ko' ? {
		title: config.title || 'MY GAME', opening: '브라우저 실행 환경 확인 중...', entering: '게임 준비 중...',
        steps: ['브라우저 호환성 확인', '엔진 로드·초기화', '게임 데이터 다운로드', '게임 파일 연결·실행', '장면 리소스 불러오기', '장면 구성', '게임 시스템 초기화', '그래픽·효과 준비', '첫 화면 표시'],
        waiting: '대기', active: '진행 중', done: '완료', error: '실패', initializing: '초기화 중',
        downloading: '엔진과 게임 데이터 불러오는 중...', preparing: '다운로드 완료 · 엔진 초기화 중...',
        sizeUnknown: '전송량 확인 중...', downloaded: '다운로드 완료', reload: '다시 불러오기',
		loading: (config.title || 'MY GAME') + ' 불러오는 중', progress: '전체 로딩 진행률',
		failed: '게임을 불러오지 못했습니다. 페이지를 새로고침해 주세요.',
		missing: '게임 실행에 필요한 브라우저 기능이 없습니다:\n'
	} : {
		title: config.title || 'MY GAME', opening: 'Checking browser support...', entering: 'Preparing the game...',
        steps: ['Browser support', 'Engine loading / initialization', 'Game data download', 'Game files / startup', 'Scene resource loading', 'Scene construction', 'Game system initialization', 'Graphics / effect preparation', 'First frame'],
        waiting: 'Waiting', active: 'In progress', done: 'Done', error: 'Failed', initializing: 'Initializing',
        downloading: 'Loading engine and game data...', preparing: 'Download complete · initializing engine...',
        sizeUnknown: 'Checking transfer size...', downloaded: 'Download complete', reload: 'Reload',
		loading: 'Loading ' + (config.title || 'MY GAME'), progress: 'Overall loading progress',
		failed: 'The game could not be loaded. Please reload the page.',
		missing: 'The following browser features required to run the game are missing:\n'
	};
	document.querySelector('#status-panel h1').textContent = messages.title;
	document.getElementById('loading-build').textContent = (language === 'ko' ? '빌드 ' : 'Build ')
		+ (config.build || 'DEV');
	document.querySelector('#status-panel .eyebrow').textContent = config.subtitle || '';
	document.getElementById('loading-build').hidden = config.showBuild === false;
	document.getElementById('loading-details').hidden = config.showDetails === false;
	if (config.accent) document.getElementById('status-panel').style.setProperty('--loading-accent', config.accent);
	document.getElementById('loading-caption').textContent = messages.opening;
	document.getElementById('status-panel').setAttribute('aria-label', messages.loading);
	statusProgress.setAttribute('aria-label', messages.progress);

    const stepNames = ['browser', 'engine', 'data', 'runtime', 'resources', 'scene', 'systems', 'graphics', 'frame'];
    const rows = Object.fromEntries(stepNames.map((name, i) => {
        const row = document.getElementById('step-' + name);
        row.dataset.number = String(i + 1).padStart(2, '0');
        row.querySelector('.label').textContent = messages.steps[i];
        return [name, row];
    }));
    const caption = document.getElementById('loading-caption');
    const bytes = document.getElementById('loading-bytes');
    const percent = document.getElementById('loading-percent');
    let engineStarted = false;
    let gameReady = false;
    let runtimeStage = -1;
    let overall = 0;
    let initializing = true;
    let engine;
    const details = window.createGodotBaseLoadingDetails({ language, stageNames: messages.steps, fail: displayFailureNotice });

    function step(name, state, detail) {
        if (!initializing) return;
        rows[name].dataset.state = state;
        rows[name].querySelector('.state').textContent = detail || messages[state];
    }
    stepNames.forEach(name => step(name, name === 'browser' ? 'active' : 'waiting'));

    function progress(value) {
        overall = Math.max(overall, Math.min(100, value));
        statusProgress.max = 100;
        statusProgress.value = overall;
        percent.textContent = Math.floor(overall) + '%';
    }

    function formatBytes(value) {
        return (Math.max(0, value) / (1024 * 1024)).toFixed(1) + ' MiB';
    }

    function updateDownload(current, total) {
        if (!initializing || runtimeStage >= 0 || engineStarted) return;
        details.download(current, total);
        bytes.textContent = total > 0 ? formatBytes(current) + ' / ' + formatBytes(total)
            : (current > 0 ? formatBytes(current) + ' · ' : '') + messages.sizeUnknown;
        if (total > 0) progress(Math.min(1, Math.max(0, current / total)) * 65);
        if (total > 0 && current >= total && rows.engine.dataset.state !== 'done') {
            step('engine', 'active', messages.initializing);
            caption.textContent = messages.preparing;
        }
    }

    function finish() {
        if (!initializing || !engineStarted || !gameReady) return;
        stepNames.forEach(name => step(name, 'done'));
        progress(100);
        details.stop();
        setStatusMode('hidden');
    }

    // start() resolves before the scene and its real render warmup are ready.
    // Only the boot scene can release this cover; late callbacks are ignored.
    window.GodotBaseBoot = {
        reportStage(name, ratio, completed = 0, total = 0) {
            if (!initializing || gameReady) return;
            const index = stepNames.indexOf(name);
            if (index < 4 || index < runtimeStage) return;
            runtimeStage = index;
            stepNames.slice(0, index).forEach(previous => step(previous, 'done'));
            const count = total > 0 ? (name === 'graphics' ? Math.floor(completed / total * 100) + '%' : completed + '/' + total) : '';
            step(name, 'active', count);
            caption.textContent = messages.steps[index] + (count ? ' · ' + count : '...');
            bytes.textContent = messages.downloaded;
            progress(Math.min(99, 70 + 29 * Math.max(0, Math.min(1, ratio))));
            details.stage(name, ratio, completed, total);
        },
        reportDetail(payload) { if (initializing && !gameReady) details.report(payload); },
        complete() { if (!initializing) return; gameReady = true; finish(); },
        fail: displayFailureNotice,
    };
    window.BlacksiteBoot = window.GodotBaseBoot; // Compatibility for older game adapters.
    let statusMode = '';
    engine = new Engine({ ...GODOT_CONFIG, onProgress: updateDownload,
        onPrintError: (...args) => { console.error(...args); details.engineError(args.join(' ')); } });

	function setStatusMode(mode) {
		if (statusMode === mode || !initializing) {
			return;
		}
		if (mode === 'hidden') {
			statusOverlay.remove();
			initializing = false;
			return;
		}
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = mode === 'progress' ? 'block' : 'none';
		statusNotice.style.display = mode === 'notice' ? 'block' : 'none';
		document.getElementById('loading-caption').hidden = mode === 'notice';
		statusMode = mode;
	}

	function setStatusNotice(text) {
		while (statusNotice.lastChild) {
			statusNotice.removeChild(statusNotice.lastChild);
		}
		const lines = text.split('\n');
		lines.forEach((line) => {
			statusNotice.appendChild(document.createTextNode(line));
			statusNotice.appendChild(document.createElement('br'));
		});
	}

	function displayFailureNotice(err) {
        if (!initializing) return;
        details.failure(err instanceof Error ? err.message : err);
        details.stop();
        console.error(err);
        for (const name of stepNames) {
            if (rows[name].dataset.state === 'active') step(name, 'error');
        }
        if (err instanceof Error) {
			setStatusNotice(messages.failed + '\n' + err.message);
		} else if (typeof err === 'string') {
			setStatusNotice(messages.failed + '\n' + err);
		} else {
			setStatusNotice(messages.failed);
		}
		setStatusMode('notice');
        const retry = document.createElement('button');
        retry.textContent = messages.reload;
        retry.style.cssText = 'display:block;min-height:44px;margin:14px auto 0;padding:8px 20px;background:#202a2b;color:#e0bf89;border:1px solid #7d8986;font:inherit;cursor:pointer';
        retry.addEventListener('click', () => window.location.reload());
        statusNotice.appendChild(retry);
        initializing = false;
        try { engine?.requestQuit?.(); } catch (_) {}
    }

    const missing = Engine.getMissingFeatures({
		threads: GODOT_THREADS_ENABLED,
	});

	if (missing.length !== 0) {
		if (GODOT_CONFIG['serviceWorker'] && GODOT_CONFIG['ensureCrossOriginIsolationHeaders'] && 'serviceWorker' in navigator) {
			setStatusMode('progress');
			let serviceWorkerRegistrationPromise;
			try {
				serviceWorkerRegistrationPromise = navigator.serviceWorker.getRegistration();
			} catch (err) {
				serviceWorkerRegistrationPromise = Promise.reject(new Error('Service worker registration failed.'));
			}
			// There's a chance that installing the service worker would fix the issue
			Promise.race([
				serviceWorkerRegistrationPromise.then((registration) => {
					if (registration != null) {
						return Promise.reject(new Error('Service worker already exists.'));
					}
					return registration;
				}).then(() => engine.installServiceWorker()),
				// For some reason, `getRegistration()` can stall
				new Promise((resolve) => {
					setTimeout(() => resolve(), 2000);
				}),
			]).then(() => {
				// Reload if there was no error.
				window.location.reload();
			}).catch((err) => {
				displayFailureNotice(err);
			});
		} else {
			// Display the message as usual
			const missingMsg = messages.missing;
			displayFailureNotice(missingMsg + missing.join('\n'));
		}
    } else {
        setStatusMode('progress');
        step('browser', 'done');
        step('engine', 'active');
        step('data', 'active');
        details.stage('engine', 0, 0, 0);
        caption.textContent = messages.downloading;
        bytes.textContent = messages.sizeUnknown;
        const executable = GODOT_CONFIG.executable;
        const pack = GODOT_CONFIG.mainPack || executable + '.pck';
        // Use the same parallel native init/preload as startGame(), while
        // retaining each promise boundary for independently completed stages.
        Promise.all([
            engine.init(executable).then(() => step('engine', 'done')),
            engine.preloadFile(pack, pack).then(() => step('data', 'done')),
        ]).then(() => {
            if (!initializing) return;
            step('runtime', 'active');
            caption.textContent = messages.steps[3] + '...';
            bytes.textContent = messages.downloaded;
            progress(70);
            details.stage('runtime', 0, 0, 0);
            // Let the browser paint the stage before native startup blocks it.
            return new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
                .then(() => {
                    if (!initializing) return;
                    return engine.start({ args: ['--main-pack', pack, ...(GODOT_CONFIG.args || [])] });
                }).then(() => {
                    if (!initializing) return;
                    engineStarted = true;
                    step('runtime', 'done');
                    if (runtimeStage < 0) window.GodotBaseBoot.reportStage('resources', 0);
                    finish();
                });
        }).catch(displayFailureNotice);
    }
}());
