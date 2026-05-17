document.addEventListener('DOMContentLoaded', function () {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (window.AOS) {
        window.AOS.init({
            duration: 800,
            once: true,
            easing: 'ease-out-cubic'
        });
    }

    const backToTopButton = document.getElementById('backToTop');

    if (backToTopButton) {
        let ticking = false;

        const updateBackToTopVisibility = function () {
            backToTopButton.classList.toggle('hidden', window.scrollY <= 300);
            backToTopButton.setAttribute('aria-hidden', window.scrollY <= 300 ? 'true' : 'false');
            ticking = false;
        };

        window.addEventListener('scroll', function () {
            if (!ticking) {
                window.requestAnimationFrame(updateBackToTopVisibility);
                ticking = true;
            }
        }, { passive: true });

        updateBackToTopVisibility();

        backToTopButton.addEventListener('click', function (event) {
            event.preventDefault();
            window.scrollTo({
                top: 0,
                behavior: prefersReducedMotion ? 'auto' : 'smooth'
            });
        });
    }

    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
        anchor.addEventListener('click', function (event) {
            const href = anchor.getAttribute('href');

            if (!href || href === '#') {
                return;
            }

            const target = document.querySelector(href);

            if (target) {
                event.preventDefault();
                target.scrollIntoView({
                    behavior: prefersReducedMotion ? 'auto' : 'smooth',
                    block: 'start'
                });

                if (!target.hasAttribute('tabindex')) {
                    target.setAttribute('tabindex', '-1');
                }

                target.focus({ preventScroll: true });
            }
        });
    });
});
