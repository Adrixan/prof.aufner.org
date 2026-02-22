/**
 * Prof. Aufner - Scripts
 * Minimal JavaScript for enhanced interactivity
 */

(function () {
    'use strict';

    // ===================================
    // Ad-Blocker Detection for Platforms
    // ===================================

    function initAdBlockerFallback() {
        const platformsMain = document.getElementById('platforms-main');
        const platformsFallback = document.getElementById('platforms-fallback');

        if (!platformsMain || !platformsFallback) return;

        // Check if the platforms grid was blocked (has no height)
        // Use a small delay to allow ad-blockers to act
        setTimeout(() => {
            const platformsGrid = platformsMain.querySelector('.platforms-grid');
            if (platformsGrid) {
                const computedStyle = window.getComputedStyle(platformsGrid);
                const isHidden = computedStyle.display === 'none' ||
                    computedStyle.visibility === 'hidden' ||
                    platformsGrid.offsetHeight === 0;

                if (isHidden) {
                    // Show fallback
                    platformsMain.hidden = true;
                    platformsFallback.hidden = false;
                }
            }
        }, 100);

        // Also detect via bait element technique
        const bait = document.createElement('div');
        bait.className = 'adsbox ad-banner ad-placeholder';
        bait.style.cssText = 'position: absolute; left: -9999px; width: 1px; height: 1px;';
        document.body.appendChild(bait);

        setTimeout(() => {
            if (bait.offsetHeight === 0 ||
                window.getComputedStyle(bait).display === 'none') {
                // Ad-blocker detected, show fallback
                const platformsGrid = platformsMain.querySelector('.platforms-grid');
                if (platformsGrid && !platformsFallback.hidden) {
                    platformsMain.hidden = true;
                    platformsFallback.hidden = false;
                }
            }
            bait.remove();
        }, 100);
    }

    // ===================================
    // Intersection Observer for Animations
    // ===================================

    const observerOptions = {
        root: null,
        rootMargin: '0px 0px -50px 0px',
        threshold: 0.1
    };

    const animationObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.animationPlayState = 'running';
                animationObserver.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe all animated elements
    function initAnimations() {
        const animatedElements = document.querySelectorAll(
            '.about-card, .platform-card, .website-card'
        );

        animatedElements.forEach(el => {
            el.style.animationPlayState = 'paused';
            animationObserver.observe(el);
        });
    }

    // ===================================
    // Active Navigation State
    // ===================================

    function updateActiveNavigation() {
        const sections = document.querySelectorAll('section[id]');
        const navLinks = document.querySelectorAll('.nav-links a');
        const scrollPosition = window.scrollY + 100;

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id');

            if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                navLinks.forEach(link => {
                    link.removeAttribute('aria-current');
                    if (link.getAttribute('href') === `#${sectionId}`) {
                        link.setAttribute('aria-current', 'page');
                    }
                });
            }
        });
    }

    // ===================================
    // Smooth Scroll for Anchor Links
    // ===================================

    function initSmoothScroll() {
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                const targetId = this.getAttribute('href');
                if (targetId === '#') return;

                const targetElement = document.querySelector(targetId);
                if (targetElement) {
                    e.preventDefault();
                    targetElement.focus({ preventScroll: true });
                    targetElement.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });

                    // Update URL without triggering scroll
                    history.pushState(null, null, targetId);
                }
            });
        });
    }

    // ===================================
    // Keyboard Navigation Enhancement
    // ===================================

    function initKeyboardNavigation() {
        // Handle Escape key for any future modals
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                // Close any open modal or dropdown (future use)
                document.activeElement.blur();
            }
        });

        // Add keyboard support for platform cards and website cards
        const interactiveCards = document.querySelectorAll('.platform-card, .website-card');
        interactiveCards.forEach(card => {
            card.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    card.click();
                }
            });
        });
    }

    // ===================================
    // Performance: Debounce & Throttle
    // ===================================

    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // ===================================
    // Initialize
    // ===================================

    function init() {
        initAnimations();
        initSmoothScroll();
        initKeyboardNavigation();
        initAdBlockerFallback();

        // Debounced scroll handler
        const debouncedNavUpdate = debounce(updateActiveNavigation, 10);
        window.addEventListener('scroll', debouncedNavUpdate, { passive: true });

        // Initial navigation state
        updateActiveNavigation();
    }

    // Run when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
