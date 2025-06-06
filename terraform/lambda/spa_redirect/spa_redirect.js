var level = 0;
var regexExpr = /^\/.+(\.\w+$)/;

function handler(event) {
    var request = event.request;
    var olduri = request.uri;

    if (event.request.uri.startsWith('/api/')) {
        return event.request;
    }

    if (isRoute(olduri)) {
        var defaultPath = '';
        
        var parts = olduri
            .replace(/^\//,'')
            .replace(/\/$/,'')
            .split('/');
        
        var nparts = parts.length;

        var limit = (level <= nparts) ? level : nparts; 

        for (var i = 0; i < limit; i++) {
            defaultPath += '/' + parts[i];
        }
        
        var newuri = defaultPath + '/index.html';

        request.uri = newuri;
        console.log('Request for [' + olduri + '], rewritten to [' + newuri + ']');
    }   

    return request;
}

function isRoute(uri) {
    return !regexExpr.test(uri);
}
