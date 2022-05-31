console.log('+Login')

Ext.define('Login.Controller', {
  extend: 'Ext.app.ViewController',
  alias: 'controller.login',
  
  init: function (view) {
    console.log(Ext.getClass(this).getName(), 'init')
  },
  
  onLoginClick: function (btn) {
    console.log(Ext.getClass(this).getName(), 'onLoginClick')
    
    var data = this.getViewModel().data
    var panel = this.lookup('loginPanel')
    
    // check
    
    if (data.login.length < 1)
      return this.lookup('login').markInvalid('Обязательное поле')
    
    if (data.passw.length < 1) {
      return this.lookup('passw').markInvalid('Обязательное поле')
    }
    
    // lock
    
    btn.disable()
    panel.setLoading({msg: 'Вход'})
    
    // request
    
    var params = {
      login: data.login,
      passw: data.passw
    }
    
    ApiReq('admin_login', params, ([ok, data]) => {
      console.log(Ext.getClass(this).getName(), 'admin_login', ok, data)
      
      btn.enable()
      panel.setLoading(false)
      
      if (ok != 'OK')
        return Ext.Msg.alert('Ошибка авторизации', `admin_login: ${ok}`)
      
      if (data.err != null)
        switch (data.err) {
          case 'e_adm_login_not_found': return Ext.Msg.alert('Ошибка', 'Неврный логин или пароль' + '<br/>' + '(код ' + data.err + ')')
          default: return Ext.Msg.alert('Ошибка', JSON.stringify(data))  // todo: обработка ошибок
        }
      
      // welcome
      
      console.log('** data.token: ' + data['token'])
      
      Ext.util.Cookies.set('token', data['token'])
      Ext.globalEvents.fireEvent('adminLoggedIn')
      
    })
    
  },
  
});


Ext.define('Login.View', {
  extend: 'Ext.container.Viewport',
  autoShow: true,
  
  viewModel: {
    data: {
      login: '',
      passw: '',
    }
  },
  
  controller: 'login',
  
  layout: {
    type: 'center',
    align: 'stretch'
  },
  
	items: [{
    
    xtype: 'panel',
    reference: 'loginPanel',
    title: 'Авторизация',
    titleAlign: 'center',
    bodyPadding: 30,
    border: true,
    
    layout: {
      type: 'vbox',
      align: 'stretch'
    },
    
    defaults: {
      xtype: 'textfield',
      labelAlign: 'right',
      labelWidth: 120,
      msgTarget: 'under',
    },
    
    items: [
      {
        fieldLabel: 'Логин',
        reference: 'login',
        bind: '{login}',
        tabIndex: 1,
      },
      {
        fieldLabel: 'Пароль',
        reference: 'passw',
        inputType: 'password',
        bind: '{passw}',
        tabIndex: 2,
      },
      {
        xtype: 'button',
        text: 'Вход',
        reference: 'loginBtn',
        handler: 'onLoginClick',
        tabIndex: 3,
      }
    ]
    
  }],
  
  onDestroy: function () {
    console.log(Ext.getClass(this).getName(), 'onDestroy')
  },
  onRemoved: function () {
    console.log(Ext.getClass(this).getName(), 'onRemoved')
  },
  onAdded: function () {
    console.log(Ext.getClass(this).getName(), 'onAdded')
  },

})