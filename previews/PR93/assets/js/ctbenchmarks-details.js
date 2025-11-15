// Custom behavior for CTBenchmarks documentation
// Ensure that certain <details> blocks start closed, regardless of browser or anchor behavior.
// We target only details elements with the `ct-collapse` class so we don't interfere with
// Documenter internals or other uses of <details>.

(function() {
    function closeCtDetails() {
        var details = document.querySelectorAll('details.ct-collapse');
        details.forEach(function(d) {
            // Remove the open attribute if present, so the block is collapsed
            d.removeAttribute('open');
        });
    }

    // Run on DOMContentLoaded
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        setTimeout(closeCtDetails, 0);
    } else {
        document.addEventListener('DOMContentLoaded', closeCtDetails);
    }

    // Also run on window load to override any Documenter.js behavior that opens <details>
    window.addEventListener('load', function() {
        setTimeout(closeCtDetails, 10);
    });

    // And on hashchange (in case a hash link opens a <details>)
    window.addEventListener('hashchange', function() {
        setTimeout(closeCtDetails, 10);
    });
})();
