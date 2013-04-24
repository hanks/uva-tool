const fs = require('fs');
const path = require('path');
const util = require('./util');

// Maps from typeName to class function
var subClasses = {}; // private static field
var normNames = {}; // normalize the type name

module.exports = (function(){
    // constructor
    function cls(app, acct)
    {
        // public instance method
        this.send = function(probNum, filePath, callback){
            // suf includes the dot
            var suf = path.extname(filePath);
            if (suf.length <= 1)
            {
                callback({message: "Cannot auto-detect language"});
                return;
            }

            suf = suf.substring(1).toLowerCase();
            this._send(probNum, filePath, suf, callback);
        };

        this.account  = function(){
            return acct;
        };
    }

    cls.normalizeType = function(s){
        return normNames[s.toLowerCase()];
    };

    // public static method
    cls.create = function(app, acct){
        var clsFn = subClasses[acct.type().toLowerCase()];
        if (clsFn) return new clsFn(app, acct);
        return null;
    };

    return cls;
})();

/*
 * Auto load the subclasses
 */
(function(){
    var files = fs.readdirSync(__dirname);
    for (var i=0; i < files.length; i++)
    {
        var match = /^adapter(\w+)/i.exec(files[i]);
        if (!match) continue;
        var modName = match[1];
        var lower = modName.toLowerCase();
        normNames[lower] = modName;
        subClasses[lower] = require('./'+files[i]);
    }
})();
