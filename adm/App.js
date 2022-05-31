console.log('+App')

Ext.define('MyApp.Application', {
  extend: 'Ext.app.Application',
  name: 'MyApp',
  
  listen: {
    global: {
      adminLoggedIn: function () {
        this.switchMainViewTo('Dashboard.View')
      },
      adminLoggedOut: function () {
        this.switchMainViewTo('Login.View')
      },
    },
  },
  
  switchMainViewTo: function (v) {
    console.log('switchMainViewTo', v)
    if (this.getMainView()) this.getMainView().destroy()
    this.setMainView(v)
  },
  
  launch: function () {
    console.log('launch', this)
    
    checkSession = () => {
      console.log('checkSession')
      
      var token = Ext.util.Cookies.get('token')
      console.log('token=' + token)
      
      if (token == null) {
        this.setMainView('Login.View')
        return
      }
      
      ApiReq('admin_state_get', {token: token}, ([status, data]) => {
        console.log('admin_state_get', status, data)
        
        if (status != 'OK')
          return Ext.Msg.alert('Ошибка восстановления сессии', `admin_state_get: "${status}"`, checkSession)
        
        if (data.err != null)
          return Ext.Msg.alert('Ошибка восстановления сессии', JSON.stringify(data), checkSession)
        
        if (data.admin == null) {
          this.setMainView('Login.View')
        } else {
          this.setMainView('Dashboard.View')
        }
        
      })
      
    }
    
    checkSession()
    
  },
  
})

Ext.application({
  name: 'MyApp',
  extend: 'MyApp.Application',
});