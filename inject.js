// For every plugin import currently on the page, that we have not yet injected.
Array.prototype.slice.call(document.head.querySelectorAll('link[data-plugin-name]')).filter(el => !el.onload._hooked).forEach(el => {
    // We wrap the original onload, which plugin-runner owns.
    // This way we get to choose when a plugin is initialized.
    const originalLoad = el.onload;
    el.onload = () => {
        // Prepare our arguments for Ace.handleOnLoad.
        const args = { document: el.import, originalLoad, pluginName: el.getAttribute("data-plugin-name") };
        const pending = window.$AcePending || (window.$AcePending = []);

        if (!window.Ace) {
            // If Ace isn't yet initialized, store the data for later.
            pending.push(args);
        } else {
            // Process pending onloads first, to retain order.
            pending.forEach(p => window.Ace.handleOnLoad(p));

            // Since Ace is now initialized, it is only good to 
            // clean up after ourselves.
            delete window.$AcePending;

            // Notify Ace of our load.
            window.Ace.handleOnLoad(args);
        }
    };

    el.onload._hooked = true;
});
