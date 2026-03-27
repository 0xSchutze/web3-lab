
// State trackers for observers
let ethCountUp = null;
let lastEthValue = -1;

document.addEventListener("DOMContentLoaded", () => {
  // 1. Initialize custom tabs
  setTimeout(initTabs, 100);

  // 2. Initialize cursor tracking glow on buttons
  initCursorTracking();

  // 3. Initialize Tippy tooltips
  if (typeof tippy !== 'undefined') {
    tippy('[data-tippy-content]', {
      theme: 'light-border',
      animation: 'scale',
      inertia: true,
      placement: 'top',
    });
  }

  // 4. Account Switcher Interaction (Clicking Address)
  const switchBtn = document.getElementById("switch-account-btn");
  if (switchBtn) {
    switchBtn.addEventListener("click", async () => {
      if (window.ethereum) {
        try {
          // Force metamask account select popup
          await window.ethereum.request({
            method: "wallet_requestPermissions",
            params: [{ eth_accounts: {} }]
          });
        } catch (error) {
          console.error("Account switch cancelled or failed", error);
        }
      } else {
        window.showToast("MetaMask is not available.", "error");
      }
    });
  }

  // 5. Setup Mutation Observers for GSAP Entrances and CountUp
  setupSmartObservers();

  // Initial connect screen animation
  if (typeof gsap !== 'undefined') {
    gsap.to('#connect-screen .anim-enter', { opacity: 1, y: 0, duration: 1, ease: 'power4.out', delay: 0.2 });
  }

  // 6. Global Token Scanner Proxy
  const globalScanBtn = document.getElementById("global-check-token");
  if (globalScanBtn) {
    globalScanBtn.addEventListener("click", () => {
      const globalInput = document.getElementById("global-token-addr");
      const targetInput = document.getElementById("withdraw-token-address");
      const targetBtn = document.getElementById("check-token-btn");

      if (!globalInput || !targetInput || !targetBtn) return;
      if (!globalInput.value.trim()) {
        window.showToast("Please enter a token address", "error");
        return;
      }

      // Hack to use app.js internal web3 bindings safely
      const originalValue = targetInput.value;
      targetInput.value = globalInput.value;

      const originalText = globalScanBtn.innerHTML;
      globalScanBtn.innerHTML = '<div class="spinner"></div>';
      globalScanBtn.style.pointerEvents = 'none';

      // Trigger app.js check-token-btn logic
      targetBtn.click();

      // Reset logic
      setTimeout(() => {
        targetInput.value = originalValue;
        globalScanBtn.innerHTML = originalText;
        globalScanBtn.style.pointerEvents = 'auto';
      }, 500);
    });
  }
});


// ── 1. Smart Observers (Decoupled from app.js) ───────────────────────────────
function setupSmartObservers() {
  // Observer for 'app' display changes (Connect -> Dashboard)
  const appNode = document.getElementById("app");
  if (appNode) {
    const appObserver = new MutationObserver((mutations) => {
      mutations.forEach((mut) => {
        if (mut.attributeName === 'style') {
          const display = window.getComputedStyle(appNode).display;
          if (display !== 'none' && !appNode.dataset.animated) {
            appNode.dataset.animated = "true"; // Prevent re-runs
            if (typeof gsap !== 'undefined') {
              gsap.to('header.anim-enter', { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out' });
              gsap.to('.anim-stagger', { opacity: 1, y: 0, scale: 1, duration: 0.8, stagger: 0.1, ease: 'back.out(1.2)', delay: 0.2 });
            }
          }
        }
      });
    });
    appObserver.observe(appNode, { attributes: true });
  }

  // Observer for 'vault-section' display changes
  const vaultNode = document.getElementById("vault-section");
  if (vaultNode) {
    const vaultObserver = new MutationObserver((mutations) => {
      mutations.forEach((mut) => {
        if (mut.attributeName === 'style') {
          const display = window.getComputedStyle(vaultNode).display;
          if (display !== 'none' && !vaultNode.dataset.animated) {
            vaultNode.dataset.animated = "true";
            if (typeof gsap !== 'undefined') {
              gsap.to('.anim-fadeup', { opacity: 1, y: 0, duration: 0.8, stagger: 0.15, ease: 'power3.out' });
              gsap.to('#tab-overview .anim-tab', { opacity: 1, duration: 0.6, delay: 0.4 });
            }
          }
        }
      });
    });
    vaultObserver.observe(vaultNode, { attributes: true });
  }

  // Observer for 'no-vault-section'
  const noVaultNode = document.getElementById("no-vault-section");
  if (noVaultNode) {
    const noVaultObserver = new MutationObserver((mutations) => {
      mutations.forEach((mut) => {
        if (mut.attributeName === 'style') {
          const display = window.getComputedStyle(noVaultNode).display;
          if (display !== 'none' && !noVaultNode.dataset.animated) {
            noVaultNode.dataset.animated = "true";
            if (typeof gsap !== 'undefined') {
              gsap.to('#no-vault-section.anim-fadeup', { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out' });
            }
          }
        }
      });
    });
    noVaultObserver.observe(noVaultNode, { attributes: true });
  }

  // Observer for ETH Balance CountUp.js
  const ethNode = document.getElementById("stat-eth");
  if (ethNode && typeof countUp !== 'undefined') {
    // Avoid infinite loop by setting a flag
    let isCounting = false;
    const ethObserver = new MutationObserver((mutations) => {
      if (isCounting) return;

      const rawText = ethNode.textContent || "";
      // Match something like "1.5000 ETH"
      const match = rawText.match(/([0-9.]+)\s*ETH/);

      if (match) {
        const val = parseFloat(match[1]);
        // Only trigger CountUp if value actually changed, otherwise it's just app.js refreshing
        if (val !== lastEthValue && !isNaN(val)) {
          isCounting = true;
          ethNode.innerHTML = ""; // Clear for countup
          if (ethCountUp) ethCountUp.update(val);
          else {
            ethCountUp = new countUp.CountUp('stat-eth', val, {
              decimalPlaces: 4,
              duration: 2.5,
              useEasing: true,
              suffix: ' ETH'
            });
            if (!ethCountUp.error) {
              ethCountUp.start();
            } else {
              console.error(ethCountUp.error);
              ethNode.textContent = rawText; // Fallback
            }
          }
          lastEthValue = val;
          // Release lock after countup finishes
          setTimeout(() => { isCounting = false; }, 2600);
        }
      }
    });
    ethObserver.observe(ethNode, { childList: true, characterData: true, subtree: true });
  }
}

// ── 2. Button Hover Tracking (Flashlight Effect) ──────────────────────
function initCursorTracking() {
  const buttons = document.querySelectorAll('.tracking-btn');
  buttons.forEach(btn => {
    btn.addEventListener('mousemove', e => {
      const rect = btn.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      btn.style.setProperty('--x', `${x}px`);
      btn.style.setProperty('--y', `${y}px`);
    });
  });
}

// ── 3. Tabs & Pill Slider ──────────────────────────────────────────────────────
function initTabs() {
  const tabBtns = document.querySelectorAll(".tab-btn");
  const tabContents = document.querySelectorAll(".tab-content");
  const indicator = document.getElementById("tab-indicator");

  function moveIndicator(btn) {
    if (!indicator || !btn) return;
    indicator.style.width = `${btn.offsetWidth}px`;
    indicator.style.left = `${btn.offsetLeft}px`;
  }

  const activeBtn = document.querySelector(".tab-btn.active");
  if (activeBtn) moveIndicator(activeBtn);

  tabBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      tabBtns.forEach((b) => b.classList.remove("active"));
      tabContents.forEach((c) => {
        c.classList.remove("active");
        // Reset GSAP animation state for active tab content
        const animCards = c.querySelectorAll('.anim-tab');
        if (animCards.length) gsap.set(animCards, { opacity: 0 });
      });

      btn.classList.add("active");
      const target = document.getElementById(btn.dataset.tab);
      if (target) {
        target.classList.add("active");
        if (typeof gsap !== 'undefined') {
          gsap.to(target.querySelectorAll('.anim-tab'), { opacity: 1, duration: 0.4, stagger: 0.1 });
        }
      }

      moveIndicator(btn);
    });
  });

  window.addEventListener("resize", () => {
    const act = document.querySelector(".tab-btn.active");
    if (act) moveIndicator(act);
  });
}

// Keep pill slider stable during owner-only visibility changes
const tabsObserver = new MutationObserver(() => {
  const act = document.querySelector(".tab-btn.active");
  const ind = document.getElementById("tab-indicator");
  if (act && ind) {
    ind.style.width = `${act.offsetWidth}px`;
    ind.style.left = `${act.offsetLeft}px`;
  }
});
const tabsCont = document.querySelector(".tabs-container");
if (tabsCont) tabsObserver.observe(tabsCont, { childList: true, subtree: true, attributes: true });


// ── 4. UI Helpers & Dynamic Overrides (Toasts & Confetti) ─────────────────────

window.showToast = function (msg, type = "info") {
  const container = document.getElementById("toast-container");
  if (!container) return;

  // Intercept success messages for Confetti!
  if (type === "success" && typeof confetti === "function") {
    // If it's a major success like creating a vault or depositing
    if (msg.toLowerCase().includes("created") || msg.toLowerCase().includes("deposited") || msg.includes("🎉")) {
      confetti({
        particleCount: 150,
        spread: 80,
        origin: { y: 0.6 },
        colors: ['#4f46e5', '#a855f7', '#38bdf8', '#10b981']
      });
    }
  }

  const icons = {
    success: '<i class="ph-fill ph-check-circle"></i>',
    error: '<i class="ph-fill ph-warning-circle"></i>',
    info: '<i class="ph-fill ph-info"></i>'
  };

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;

  toast.innerHTML = `
    <div class="toast-icon-wrap">
      ${icons[type] || icons.info}
    </div>
    <span>${msg}</span>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    if (toast.parentNode) toast.remove();
  }, 4000);
};

window.setBtnLoading = function (id, loading) {
  const btn = document.getElementById(id);
  if (!btn) return;

  if (loading) {
    if (!btn._originalContent) btn._originalContent = btn.innerHTML;
    const width = btn.offsetWidth;
    btn.style.width = width + "px";
    btn.innerHTML = '<div class="spinner"></div>';
    btn.disabled = true;
  } else {
    if (btn._originalContent) {
      btn.innerHTML = btn._originalContent;
    }
    btn.style.width = "";
    btn.disabled = false;
  }
};
