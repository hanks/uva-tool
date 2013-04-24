const fs = require('fs');
const path = require('path');
const util = require('./util');
const Account = require('./account');
const Adapter = require('./adapter');

module.exports = (function(){
    function cls()
    {
        /** Current account object */
        var curAcct = null;
        
        /** Current adapter object */
        var curAdap = null;
        
        /** Adapter specific data.
         *  E.g., adapData['uva'] is the UVA adapter specific data.
         */
        var adapData = {};

        /** All accounts. */
        var accts = []; 

        function findAcct(type, user)
        {
            for (var i=0; i < accts.length; i++)
            {
                if (accts[i].match(type, user))
                    return i;
            }

            return -1;
        }

        this.load = function(filePath){
            var settings = JSON.parse(fs.readFileSync(filePath, {encoding: 'utf8'}));
            adapData = settings.adapData;
            accts = settings.accts;
        
            for (var i=0; i < accts.length; i++)
            {
                accts[i] = new Account(accts[i]);
            }

            curAcct = null;
            curAdap = null;
            if (settings.curAcct && settings.curAcct.length === 2)
            {
                this.use(settings.curAcct[0], settings.curAcct[1]);
            }
        };

        this.save = function(filePath){
            var settings = {
                curAcct: curAcct ? [curAcct.type(), curAcct.user()] : null,
                adapData : adapData,
                accts: accts
            };

            var opts = {encoding: 'utf8', mode: 0600};
            fs.writeFileSync(filePath, JSON.stringify(settings), opts);
        };

        this.getAdapterData = function(type){
            type = type.toLowerCase();
            return adapData[type] || (adapData[type] = {});
        };

        /**
         * Adds a new account, or replaces an existing one.
         * @return boolean true if acct is added ok.
         */
        this.add = function(acct){
            var idx = findAcct(acct.type(), acct.user());
            if (idx >= 0)
            {
                accts[idx] = acct;
                if (curAcct && curAcct.match(acct.type(), acct.user()))
                {
                    curAcct = acct;
                    curAdap = Adapter.create(this, acct);
                }
                return true;
            }

            accts.push(acct);
            return true;
        };

        /**
         * Removes an existing account which must not be the current account.
         * @return boolean true if account is removed.
         */
        this.remove = function(type, user){
            if (curAcct && curAcct.match(type, user))
                return false;

            var idx = findAcct(type, user);
            if (idx < 0) return false;

            accts.splice(idx, 1);
            return true;
        };

        this.getCurrent = function(){
            return curAcct;
        };

        this.getCurrentAdapter = function(){
            return curAdap;
        };

        this.useNone = function(){
            curAdap = curAcct = null;
        };

        /**
         * Sets an account as current.
         * @return boolean true if account is set as current.
         */
        this.use = function(type, user){
            var idx = findAcct(type, user);
            if (idx < 0) return false;
            
            var a = Adapter.create(this, accts[idx]);
            if (!a) return false;

            curAcct = accts[idx];
            curAdap = a;
            return true;
        };

        /**
         * Gets all accounts. Do not modify directly.
         * @return array of account objects.
         */
        this.getAll = function(){
            return accts;
        };
    }

    return cls;
})();
