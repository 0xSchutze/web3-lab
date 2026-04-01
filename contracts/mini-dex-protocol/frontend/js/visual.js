/**
 * Mini-DEX — Visual Effects Engine
 * 
 * Canvas mesh gradient, staggered animations, 
 * number counters, button ripple effects
 * Pure JS — no external dependencies
 */

(function() {
    'use strict';

    // ═══════════════ ANIMATED MESH GRADIENT (Canvas) ═══════════════
    
    const canvas = document.createElement('canvas');
    canvas.id = 'meshGradient';
    canvas.style.cssText = 'position:fixed;inset:0;z-index:0;pointer-events:none;opacity:0.4;';
    document.body.prepend(canvas);
    const ctx = canvas.getContext('2d');

    const blobs = [
        { x: 0.15, y: 0.2, r: 0.35, color: [99, 179, 237], speed: 0.0003, phase: 0 },
        { x: 0.8, y: 0.85, r: 0.3, color: [167, 139, 250], speed: 0.0004, phase: 2 },
        { x: 0.5, y: 0.5, r: 0.25, color: [246, 173, 85], speed: 0.0002, phase: 4 },
        { x: 0.3, y: 0.8, r: 0.2, color: [104, 211, 145], speed: 0.00035, phase: 1 },
    ];

    function resizeCanvas() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    function drawMesh(time) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        for (const blob of blobs) {
            const cx = canvas.width * (blob.x + Math.sin(time * blob.speed + blob.phase) * 0.08);
            const cy = canvas.height * (blob.y + Math.cos(time * blob.speed * 0.7 + blob.phase) * 0.06);
            const radius = Math.min(canvas.width, canvas.height) * blob.r;
            
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
            const [r, g, b] = blob.color;
            grad.addColorStop(0, `rgba(${r},${g},${b},0.08)`);
            grad.addColorStop(0.5, `rgba(${r},${g},${b},0.03)`);
            grad.addColorStop(1, 'rgba(0,0,0,0)');
            
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        }
        
        requestAnimationFrame(drawMesh);
    }
    requestAnimationFrame(drawMesh);

    // ═══════════════ STAGGERED ENTRANCE ANIMATIONS ═══════════════

    // Observe new items being added to containers and animate them in
    const staggerTargets = [
        'sidebarWalletAssets', 'sidebarUserPairs', 'sidebarActivity'
    ];

    const staggerStyle = document.createElement('style');
    staggerStyle.textContent = `
        @keyframes staggerIn {
            from { opacity: 0; transform: translateX(-12px); }
            to { opacity: 1; transform: translateX(0); }
        }
        .stagger-item {
            animation: staggerIn 0.35s cubic-bezier(0.16, 1, 0.3, 1) both;
        }
        @keyframes countPulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
        .count-pulse {
            animation: countPulse 0.3s ease;
        }
        .ripple-effect {
            position: absolute;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.15);
            transform: scale(0);
            animation: ripple 0.5s ease-out forwards;
            pointer-events: none;
        }
        @keyframes ripple {
            to { transform: scale(3); opacity: 0; }
        }
        .explorer-card {
            opacity: 0;
            animation: cardPop 0.4s cubic-bezier(0.16, 1, 0.3, 1) both;
        }
    `;
    document.head.appendChild(staggerStyle);

    for (const id of staggerTargets) {
        const container = document.getElementById(id);
        if (!container) continue;
        
        const observer = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node.nodeType === 1 && !node.classList.contains('empty-state')) {
                        const siblings = container.querySelectorAll('.token-row, .activity-row');
                        const idx = Array.from(siblings).indexOf(node);
                        node.classList.add('stagger-item');
                        node.style.animationDelay = `${idx * 60}ms`;
                    }
                }
            }
        });
        observer.observe(container, { childList: true });
    }

    // ═══════════════ EXPLORER CARD STAGGERED POP ═══════════════

    const explorerObserver = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
            let cardIdx = 0;
            for (const node of mutation.addedNodes) {
                if (node.nodeType === 1 && node.classList.contains('explorer-card')) {
                    node.style.animationDelay = `${cardIdx * 50}ms`;
                    cardIdx++;
                }
            }
        }
    });

    // Observe both explorer grids
    document.querySelectorAll('.explorer-grid').forEach(grid => {
        explorerObserver.observe(grid, { childList: true });
    });

    // Add cardPop keyframes
    const explorerStyle = document.createElement('style');
    explorerStyle.textContent = `
        @keyframes cardPop {
            from { opacity: 0; transform: translateY(10px) scale(0.95); }
            to { opacity: 1; transform: translateY(0) scale(1); }
        }
    `;
    document.head.appendChild(explorerStyle);

    // ═══════════════ BUTTON RIPPLE EFFECT ═══════════════

    document.addEventListener('click', (e) => {
        const btn = e.target.closest('.btn-action, .btn-primary, .tab-btn');
        if (!btn || btn.disabled) return;
        
        // Ensure relative positioning
        const computed = getComputedStyle(btn);
        if (computed.position === 'static') btn.style.position = 'relative';
        btn.style.overflow = 'hidden';
        
        const ripple = document.createElement('span');
        ripple.className = 'ripple-effect';
        
        const rect = btn.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        ripple.style.width = ripple.style.height = `${size}px`;
        ripple.style.left = `${e.clientX - rect.left - size / 2}px`;
        ripple.style.top = `${e.clientY - rect.top - size / 2}px`;
        
        btn.appendChild(ripple);
        ripple.addEventListener('animationend', () => ripple.remove());
    });

    // ═══════════════ BALANCE COUNT-UP ANIMATION ═══════════════

    window.animateNumber = function(element, targetValue, duration = 600) {
        const start = parseFloat(element.textContent) || 0;
        const diff = targetValue - start;
        if (Math.abs(diff) < 0.0001) return;
        
        const startTime = performance.now();
        
        function step(now) {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            // Ease out cubic
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = start + diff * eased;
            
            element.textContent = current.toFixed(4);
            
            if (progress < 1) {
                requestAnimationFrame(step);
            } else {
                element.classList.add('count-pulse');
                setTimeout(() => element.classList.remove('count-pulse'), 300);
            }
        }
        
        requestAnimationFrame(step);
    };

    // ═══════════════ SMOOTH PANEL HEIGHT TRANSITIONS ═══════════════

    // Wrap panel transitions with height animation
    const originalPanelReveal = document.querySelector('.panel.active');
    
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            // Let the main handler do class toggling, we just add visual flair
            requestAnimationFrame(() => {
                const activePanel = document.querySelector('.panel.active');
                if (activePanel) {
                    activePanel.style.willChange = 'transform, opacity';
                    setTimeout(() => { activePanel.style.willChange = 'auto'; }, 400);
                }
            });
        });
    });

    // ═══════════════ SIDEBAR HOVER GLOW ═══════════════

    const sidebar = document.querySelector('.sidebar');
    if (sidebar) {
        sidebar.addEventListener('mousemove', (e) => {
            const rect = sidebar.getBoundingClientRect();
            const y = e.clientY - rect.top;
            sidebar.style.setProperty('--glow-y', `${y}px`);
        });

        const glowStyle = document.createElement('style');
        glowStyle.textContent = `
            .sidebar::before {
                content: '';
                position: absolute;
                top: var(--glow-y, -100px);
                left: 0;
                width: 100%;
                height: 200px;
                background: radial-gradient(ellipse at 30% 50%, rgba(99,179,237,0.03) 0%, transparent 70%);
                transform: translateY(-50%);
                pointer-events: none;
                transition: top 0.3s ease;
                z-index: 0;
            }
            .sidebar { position: relative; }
            .sidebar > * { position: relative; z-index: 1; }
        `;
        document.head.appendChild(glowStyle);
    }

    // ═══════════════ MODAL BACKDROP CLICK-TO-CLOSE ═══════════════

    document.querySelectorAll('.modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                overlay.classList.remove('active');
            }
        });
    });

    console.log('%c✦ Visual Engine loaded', 'color: #63b3ed; font-weight: bold;');
})();
