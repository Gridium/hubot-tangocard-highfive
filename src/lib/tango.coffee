TangoApp = require './api/tangocard'
http = require('http');

module.exports = (robot) ->
    app = new TangoApp(robot)

    # Environment vars
    cust = process.env.HUBOT_TANGOCARD_CUSTOMER
    acct = process.env.HUBOT_TANGOCARD_ACCOUNT
    cc = process.env.HUBOT_TANGOCARD_CC
    auth = process.env.HUBOT_TANGOCARD_AUTH
    amtToFund = (process.env.HUBOT_HIGHFIVE_AWARD_LIMIT || 150) * 10 * 100 # in cents

    order: (msg, from_user, to_user, dollars, reason, callback) ->

        doOrder = ->
            # Place an order
            message = "High five for #{reason}!"
            app.orderGiftCard cust, acct, 'High-five',
                                      Math.floor(dollars*100),
                                      from_user.real_name, 'High Five!',
                                      to_user.real_name, to_user.email,
                                      message
            , (resp) ->
                robot.logger.debug "TANGO order response #{JSON.stringify resp}"
                unless resp.success
                    errmsg = resp.invalid_inputs_message || resp.error_message || resp.denial_message
                    return msg.reply "(Problem ordering gift card: '#{errmsg}'. Check the logs; you might want 'highfive config'.)"

                # Order completed successfully. Trigger success callback
                callback resp.order


        # Check account status
        app.getAccountStatus cust, acct, (resp) ->
            unless resp.success
                robot.logger.info "TANGO account status #{JSON.stringify resp}"
                return msg.reply "(Problem getting Tango Card status: '#{resp.error_message}'. Check the logs; you might want `highfive config`.)"

            return doOrder() if resp.account?.available_balance >= dollars*100

            http.get {'host': 'api.ipify.org', 'port': 80, 'path': '/'}, (resp) ->
              resp.on 'data', (ip_addr) ->
                ip_addr = "#{ip_addr}" #convert to a string instead of byte buffer
                robot.logger.info "My public IP address is: " + ip_addr

                app.fundAccount cust, acct, amtToFund, ip_addr, cc, auth, (resp) ->
                    return doOrder() if resp.success
                    robot.logger.info "TANGO funding response #{JSON.stringify resp}"
                    msg.reply "(Problem funding Tango Card account: '#{resp.denial_message}'. Check the logs; you might want `highfive config`.)"