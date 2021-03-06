const http = require('http');
const qs = require('querystring');
const crypto = require('crypto');
const fs = require('fs');

const ATTRIB_PATTERN =
    // group 1: attrib name (allowing namespace)
    // group 2: value including quote chars if any
    /([\w:]+)\s*=\s*("[^"]*"|'[^']*'|\S*)/gi;

    
(function(obj){

obj.createEndCallback = function(callback){
    var buf = '';
    return function(inMsg){
        inMsg.setEncoding('utf8');
        inMsg.on('readable', function(){buf += inMsg.read() || '';})
             .on('end', function(){callback(buf, inMsg);});
    };
};

/**
 * Removes surrounding quote chars (" or ') from a string.
 * Any whitespace surrounded by the quote chars are preserved but 
 * whitespaces outside of the quote chars are removed. If no quote chars
 * are present the entire string is trimmed of whitespaces.
 * The string is processed adhering to the following rules:
 * - the starting and ending quote chars must be the same.
 * - if the starting or ending quote char is present, the other must also
 *    be present, that is, there must be no unmatched quote char.
 * <pre>
 * Examples: 
 * String s = "  ' hello '  "; // unquote(s) returns "' hello '"
 * String s = "  'hello   ";   // unquote(s) will throw an exception
 * String s = " hello ";       // unquote(s) returns "hello"
 * </pre> 
 * @param s
 * @exception if at least one 
 * of the rules is violated. 
 */
obj.unquote = function(s){
    s = s.trim();
    if (s.length >= 1)
    {
        var start = s.charAt(0);
        var end = s.length >= 2 ? s.charAt(s.length-1) : 0;
        var isQuote = 
           (start === '"' || start === '\'' ||
            end   === '"' || end   === '\'');
            
        if (isQuote)
        {
            if (start === end)
                return s.substring(1, s.length-1);
                
            throw {message: "mismatched quote chars"};
        }
    }

    return s;
};

/**
 * Parses an HTML fragment containing attribute pairs without the
 * tag name, in to a map.
 * This is a forgiving parser that does not adhere strictly to XML rules,
 * but well-formed XML are guaranteed to be parsed correctly.
 * @param html This must be in the format: attrib1="value" attrib2="value"
 * @return Map of attrib-value pairs. The names and values are NOT HTML
 * decoded.
 */
obj.parseAttribs = function(html){
    var match, pairs = {};
    while (match = ATTRIB_PATTERN.exec(html))
    {
        pairs[match[1]] = obj.unquote(match[2]);
    }
    return pairs;
};

obj.getUserHomePath = function () {
    var p = process.env[(process.platform == 'win32') ? 'USERPROFILE' : 'HOME'];
    if (p) return p;
    throw {message: "Cannot determine user home dir"};
};

obj.htmlDecodeSimple = function(s){
    return s.replace(/&apos;/g, '\'')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&amp;/g, '&');
};

/**
 * @param method GET or POST
 * @param host domain name
 * @param path Absolute path e.g. /index.html
 * @param callback response callback function
 */
obj.createReq = function(method, host, path, callback){
    var options = {
        hostname: host,
        path: path,
        method: method,
        
        // typical headers to disguise our identity
        headers: {
            'Referer': 'http://'+host+path,
            'Accept-Charset': 'utf-8,ISO-8859-1',

            // Use chunked so we don't have to send content-length
            'Transfer-Encoding': 'chunked',
            
            // no gzip :(
            //'Accept-Encoding': 'gzip,deflate',
        
            'Accept-Language': 'en-US,en;q=0.8',
            'User-Agent' :  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) "+
                            "AppleWebKit/537.17 (KHTML, like Gecko) "+
                            "Chrome/24.0.1312.57 Safari/537.17",
            "Accept" : "text/html, application/xml, text/xml, */*"
        }
    };

    return http.request(options, callback);
};

obj.writePostData = function(httpReq, data){
    var qstr = qs.stringify(data);
    httpReq.setHeader('Content-Type',
            "application/x-www-form-urlencoded; charset=UTF-8"); 
    httpReq.end(qstr, 'utf8');
};

obj.writeFormData = function(httpReq, data){
    var boundBytes = crypto.pseudoRandomBytes(16);
    var boundStr = (new Buffer(boundBytes)).toString('hex');
    
    httpReq.setHeader('Content-Type', 
        'multipart/form-data; boundary='+boundStr);

    var bufCap = 1<<16;
    var buf = new Buffer(bufCap);
    
    for (var key in data)
    {
        var val = data[key];
        httpReq.write('--'+boundStr, 'ascii');

        // file upload?
        if (typeof val === 'object' && val.filePath)
        {
            httpReq.write("\r\nContent-Disposition: form-data; name=\""+ key +
                "\"; filename=\""+val.filePath+"\"\r\n"+
                "Content-Type: application/octet-stream\r\n"+
                "Content-Transfer-Encoding: binary\r\n\r\n", "utf8");

            var fd = fs.openSync(val.filePath, 'r');
            var bufSize = 0;

            while(true)
            {
                // read til buffer is full
                while (bufSize < bufCap)
                {
                    var nread = fs.readSync(fd, buf, bufSize, bufCap-bufSize, null);
                    if (nread == 0) break;
                    bufSize += nread;
                }

                if (bufSize === bufCap)
                {
                    bufSize = 0;
                    httpReq.write(buf);
                    continue;
                }

                httpReq.write(buf.slice(0, bufSize));
                break;
            }

            fs.closeSync(fd);
            httpReq.write("\r\n", 'ascii');
        }
        else
        {
            httpReq.write("\r\nContent-Disposition: form-data; name=\""+ key +"\"\r\n\r\n", 'utf8');
            httpReq.write(val+"\r\n", 'utf8');
        }
    }

    httpReq.end('--'+boundStr+"--\r\n",'ascii');
};

/**
 * Gets a semi-colon-separated list of cookies from the Set-Cookie headers,
 * without the cookies' metadata such as expiry and path.
 * The cookie keys and values are not decoded.
 * @return null if the cookies are not found.
 */
obj.getCookies = function(inMsg){
    
    var cookies = inMsg.headers["set-cookie"];
    if (typeof cookies === 'string')
    {
        cookies = [cookies];
    }
    else if (!cookies)
        return null;

    function get(line)
    {
        var tokens = line.split(';');
        
        // Cookie should be the first token
        if (tokens.length >= 1)
        {
            var pair = tokens[0].split("=");
            if (pair.length != 2) return null;

            var key = pair[0].trim();
            var value = pair[1].trim();

            return {key: key, value: value};
        }

        return null;
    }

    var z = '';
    var sep = '';
    for (var i = 0; i < cookies.length; i++)
    {
        var cookie = get(cookies[i]);
        if (!cookie) continue;
        z += sep + cookie.key + '=' + cookie.value;
        sep = '; ';
    }

    return z;
};

})(module.exports);
