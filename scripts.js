/**
 * Prof. Aufner - Scripts
 * Einzige Funktion: aktiven Navigationspunkt per aria-current markieren.
 * Die Seite funktioniert vollständig ohne JavaScript.
 */
(function () {
    'use strict';

    var links = Array.prototype.slice.call(
        document.querySelectorAll('.nav-links a[href^="/#"]')
    );
    if (!links.length || !('IntersectionObserver' in window)) return;

    var byId = {};
    links.forEach(function (link) {
        byId[link.hash.slice(1)] = link;
    });

    var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
            if (!entry.isIntersecting) return;
            links.forEach(function (link) {
                link.removeAttribute('aria-current');
            });
            var active = byId[entry.target.id];
            if (active) active.setAttribute('aria-current', 'location');
        });
    }, { rootMargin: '-30% 0px -60% 0px', threshold: 0 });

    Object.keys(byId).forEach(function (id) {
        var section = document.getElementById(id);
        if (section) observer.observe(section);
    });
})();
