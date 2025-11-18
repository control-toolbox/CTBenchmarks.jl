// Custom behavior for CTBenchmarks documentation
// Ensure that certain <details> blocks start closed, regardless of browser or anchor behavior.
// We target only details elements with the `ct-collapse` class so we don't interfere with
// Documenter internals or other uses of <details>.

(function() {
    var ctCloserInterval = null;

    function closeCtDetails() {
        var details = document.querySelectorAll('details.ct-collapse');
        details.forEach(function(d) {
            // Remove the open attribute if present, so the block is collapsed
            d.open = false;
            d.removeAttribute('open');
        });
    }

    function scheduleCtDetailsClose(durationMs) {
        if (ctCloserInterval !== null) {
            clearInterval(ctCloserInterval);
            ctCloserInterval = null;
        }

        var start = Date.now();
        closeCtDetails();

        ctCloserInterval = setInterval(function() {
            closeCtDetails();
            if (Date.now() - start >= durationMs) {
                clearInterval(ctCloserInterval);
                ctCloserInterval = null;
            }
        }, 50);
    }

    function initCtDetails() {
        var blocks = document.querySelectorAll('.ctdetails');
        blocks.forEach(function(block) {
            var summary = block.querySelector('.ctdetails-summary');
            var body = block.querySelector('.ctdetails-body');
            if (!summary || !body) return;

            block.classList.remove('ctdetails-open');
            body.hidden = true;
            summary.setAttribute('aria-expanded', 'false');

            function toggle() {
                var open = !block.classList.contains('ctdetails-open');
                block.classList.toggle('ctdetails-open', open);
                body.hidden = !open;
                summary.setAttribute('aria-expanded', String(open));
            }

            summary.addEventListener('click', toggle);
            summary.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    toggle();
                }
            });
        });
    }

    // Run on DOMContentLoaded
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        scheduleCtDetailsClose(800);
        initCtDetails();
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            scheduleCtDetailsClose(800);
            initCtDetails();
        });
    }

    // Also run on window load to override any Documenter.js behavior that opens <details>
    window.addEventListener('load', function() {
        scheduleCtDetailsClose(800);
    });

    // And on hashchange (in case a hash link opens a <details>)
    window.addEventListener('hashchange', function() {
        scheduleCtDetailsClose(800);
    });
})();
