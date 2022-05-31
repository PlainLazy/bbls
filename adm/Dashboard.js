console.log('+Dashboard')


opened_windows = {}




Ext.define('BubblePlayersModel', {
  extend: 'Ext.data.Model',
  idProperty: 'id',  // same as default
  fields: [
    {
      name: 'ctime',
      type: 'date',
      dateFormat: 'U',  // https://docs.sencha.com/extjs/6.2.0/classic/Ext.Date.html
    },
    'dev_id',
    'fb_id',
  ],
});


Ext.define('BubblePlayersProxy', {
  extend: 'Ext.data.proxy.Ajax',
  alias: 'proxy.BubblePlayersProxy',
  
  url: '_do_not_remove_it',
  
  useDefaultXhrHeader: false,  // disable OPTIONS request
  
  sendRequest: function (request) {
    console.log('MyBaseProxy.sendRequest', request)
    console.log('MyBaseProxy.sendRequest', this)
    
    var conf = request.getCurrentConfig()
    console.log('originqal conf', conf)
    
    var proto = /http(s?):/.test(location.protocol) ? '//' : 'http://'
    //conf.url = `${proto}apps.blissgame.org/api/admin_players_list`
    conf.url = `${proto}${location.host}/api/admin_players_list`
    conf.method = 'POST'
    conf.disableCaching = false
    conf.withCredentials = true
    
    var p = {}
    
    if ('limit' in request._params) p.limit = request._params.limit
    if ('start' in request._params) p.offset = request._params.start
    if ('sort' in request._params) p.order = request._params.sort
    if ('dir' in request._params) p.dir = request._params.dir
    
    /*
    p.filters = []
    for (f of request._operation._filters) {
      console.log('* filter', f, ' = ', f._property, f._value)
      if (f._property == 'ctime') {
        p.filters.push([f._property, f._operator, Math.floor(f._value.getTime() / 1000)])
      }
    }
    if (p.filters.length == 0) delete p.filters
    */
    
    p.filters = {}
    for (f of request._operation._filters) {
      if (f._property == 'id') { p.filters['id'] = f._value }
      if (f._property == 'dev_id') { p.filters['dev_id'] = f._value }
      if (f._property == 'fb_id') { p.filters['fb_id'] = f._value }
    }
    
    conf.params = JSON.stringify(p)
    
    request.setRawRequest(Ext.Ajax.request(conf));
    this.lastRequest = request;
    return request;
  },
  
  noCache: false,
  simpleSortMode: true,  // только по одному столбцу
  reader: {
    type: 'json',
    rootProperty: 'data',
    totalProperty: 'total'
  },
  
});


Ext.define('BubblePlayersBufferedStore', {
  extend: 'Ext.data.BufferedStore',
  model: 'BubblePlayersModel',
  alias: 'store.bubble_players_store',
  remoteSort: true,
  remoteFilter: true,
  //leadingBufferZone: 200,
  //trailingBufferZone: 25,
  pageSize: 200,
  autoLoad: false,
  proxy: 'BubblePlayersProxy',
  fields: ['id', 'ctime', 'dev_id', 'fb_id'],
})


Ext.define('Comp.Grid', {
  extend: 'Ext.grid.Panel',
  xtype: 'BubblePlayersGrid',
  loadMask: true,
  selModel: {
    mode: 'SINGLE',  // MULTI
    pruneRemoved: false
  },
  plugins: 'gridfilters',
  emptyText: 'Пусто',
  forceFit: true,
  
  store: {type: 'bubble_players_store'},
  
  columns: [
    
    {
      text: 'ID',
      dataIndex: 'id',
      width: 100, sortable: true, groupable: false, filter: true, hidden: true
    },
    
    {
      text: 'Создан',
      dataIndex: 'ctime',
      width: 150, sortable: true, groupable: false, xtype: 'datecolumn', format: 'd.m.Y'/*,
      filter: {
        type: 'date',
        menuItems: ['lt', 'gt', 'eq'],  // eq
        fields: {
          lt: { text: 'Ранее чем' },
          gt: { text: 'Позднее чем' },
          eq: { text: 'Точная дата', },
        },
      },*/
    },
    
    {
      text: 'Device',
      dataIndex: 'dev_id',
      width: 200, sortable: true, groupable: false, filter: true
    },
    
    {
      text: 'FB',
      dataIndex: 'fb_id',
      width: 200, sortable: true, groupable: false, filter: true
    },
    
  ],
  
  listeners : {
    'rowdblclick': function (grid, row, e) {
      //console.log('rowdblclick', row)
      var w = Ext.create('PlayerStateWindow')
      w['player_list_data'] = row.data
      w.show()
      opened_windows[w.id] = w
    }
  }
  
})


Ext.define('PlayersWindow', {
  extend: 'Ext.window.Window',
  title: 'Игроки',
  maximized: false, maximizable: true, minimizable: false,
  monitorResize: true,
  closable: true,
  width: 800, height: 450,
  resizable: true,
  modal: false,
  padding: 0, bodyPadding: 0,
  liveDrag: true,
  layout: 'border',
  
  items: [
    {
      xtype: 'panel',
      region: 'center',
      bodyPadding: 0,
      border: false,
      layout: 'fit',
      height: '100%',
      flex: 1,
      items: [
        {
          xtype: 'BubblePlayersGrid',
          laypot: 'fit',
          reference: 'my_grid',
        },
      ],
    },
  ],
  
  listeners: {
    'close': function (win) {
      //console.log('close', win)
      delete opened_windows[win.id]
    }
  }
  
})



Ext.define('MyPlayerStateController', {
  extend: 'Ext.app.ViewController',
  alias: 'controller.MyPlayerStateController',
  
  init: function (view) {
    console.log(Ext.getClass(this).getName(), 'init')
  },
  
  onShow: function (win) {
    //console.log('MyPlayerStateController.show', win.id, win['player_list_data'])
    
    var panel = this.view.lookup('playerStatePanel')
    panel.setLoading({msg: 'Загрузка'})
      
    ApiReq('admin_player_state_get', {player: this.view['player_list_data'].id}, ([ok, data]) => {
      
      panel.setLoading(false)
      
      if (ok != 'OK')
        return Ext.Msg.alert('Ошибка запроса состояния игрока', `admin_player_state_get: ${ok}`)
      
      if (data.err != null)
        switch (data.err) {
          default: return Ext.Msg.alert('Ошибка', JSON.stringify(data))
        }
      
      this.getViewModel().set('player_state', JSON.stringify(data['data'], null, '    '))
      
    })
    
  },
  
  onClose: function (win) {
    delete opened_windows[win.id]
  },
  
  onSaveClick: function (btn, ev) {
    console.log('onSaveClick', this)
    
    try {
      var state = JSON.parse(this.getViewModel().data.player_state)
    } catch (e) {
      return Ext.Msg.alert('Ошибка воода данных', 'Не удалось преобразовать указанное состояние игрока в JSON документ')
    }
    
    //console.log('state', state)
    
    var panel = this.lookup('playerStatePanel')
    panel.setLoading({msg: 'Сохранение'})
    
    ApiReq('admin_player_state_set', {player: this.view['player_list_data'].id, data: state}, ([ok, data]) => {
      
      panel.setLoading(false)
      
      if (ok != 'OK')
        return Ext.Msg.alert('Ошибка сохранения состояния игрока', `admin_player_state_set: ${ok}`)
      
      if (data.err != null)
        switch (data.err) {
          default: return Ext.Msg.alert('Ошибка', JSON.stringify(data))
        }
      
      
      
    })
    
  },
  
})


Ext.define('PlayerStateWindow', {
  extend: 'Ext.window.Window',
  title: 'Состояние игрока',
  maximized: false, maximizable: true, minimizable: false,
  monitorResize: true,
  closable: true,
  width: 500, height: 600,
  resizable: true,
  modal: false,
  padding: 0, bodyPadding: 0,
  liveDrag: true,
  layout: 'border',
  
  viewModel: {
    data: {
      player_state: ''
    }
  },
  
  controller: 'MyPlayerStateController',
  
  items: [
    {
      xtype: 'panel',
      reference: 'playerStatePanel',
      region: 'center',
      bodyPadding: 0,
      border: false,
      layout: 'fit',
      height: '100%',
      flex: 1,
      items: [
        {
          xtype: 'textareafield',
          bind: '{player_state}',
          grow: false,
          name: 'player_state',
          fieldLabel: 'Состояние',
          anchor: '100%'
        },
      ],
      bbar: [
        {
          text: 'Сохранить',
          handler: 'onSaveClick',
        },
      ],
    },
  ],
  
  listeners : {
    'show': 'onShow',
    'close': 'onClose'
  }
  
})








Ext.define('MyStatisticsController', {
  extend: 'Ext.app.ViewController',
  alias: 'controller.MyStatisticsController',
  
  init: function (view) {
    console.log(Ext.getClass(this).getName(), 'init')
  },
  
  onClose: function (win) {
    delete opened_windows[win.id]
  },
  
  onCalculateClick: function (btn, ev) {
    console.log('onCalculateClick', this)
    
    var panel = this.lookup('statisticsPanel')
    panel.setLoading({msg: 'Формирование'})
    
    var vmd = this.getViewModel().data
    //console.log('from', vmd.date_from, vmd.time_from)
    //console.log('to', vmd.date_to, vmd.time_to)
    
    var params = {}
    
    if (vmd.date_from != null) {
      var d = new Date(vmd.date_from.getFullYear(), vmd.date_from.getMonth(), vmd.date_from.getDate())
      if (vmd.time_from != null) {
        d.setHours(vmd.time_from.getHours())
        d.setMinutes(vmd.time_from.getMinutes())
      }
      params['utc_min'] = Math.floor(d.getTime() / 1000)
    }
    
    if (vmd.date_to != null) {
      var d = new Date(vmd.date_to.getFullYear(), vmd.date_to.getMonth(), vmd.date_to.getDate())
      if (vmd.time_to != null) {
        d.setHours(vmd.time_to.getHours())
        d.setMinutes(vmd.time_to.getMinutes())
      }
      params['utc_max'] = Math.floor(d.getTime() / 1000)
    }
    
    ApiReq('admin_statistics_get', params, ([ok, data]) => {
      
      panel.setLoading(false)
      
      if (ok != 'OK')
        return Ext.Msg.alert('Ошибка формирования статистики', `admin_statistics_get: ${ok}`)
      
      if (data.err != null)
        switch (data.err) {
          default: return Ext.Msg.alert('Ошибка', JSON.stringify(data))
        }
      
      var d = []
      for (var k in data['statistics']) {
        var v = data['statistics'][k]
        var vv = {key: k}
        for (var l in v) vv[l] = v[l]
        d.push(vv)
      }
      
      var s = Ext.data.StoreManager.lookup('MyStatStore')
      s.setData(d)
      
    })
    
    
  },
  
})




Ext.define('MyStatistics2Controller', {
  extend: 'Ext.app.ViewController',
  alias: 'controller.MyStatistics2Controller',
  
  init: function (view) {
    console.log(Ext.getClass(this).getName(), 'init')
  },
  
  onClose: function (win) {
    delete opened_windows[win.id]
  },
  
  onCalculateClick: function (btn, ev) {
    console.log('onCalculateClick', this)
    
    var panel = this.lookup('statistics2Panel')
    panel.setLoading({msg: 'Формирование'})
    
    var vmd = this.getViewModel().data
    //console.log('from', vmd.date_from, vmd.time_from)
    //console.log('to', vmd.date_to, vmd.time_to)
    
    var params = {}
    
    if (vmd.date_from != null) {
      var d = new Date(vmd.date_from.getFullYear(), vmd.date_from.getMonth(), vmd.date_from.getDate())
      if (vmd.time_from != null) {
        d.setHours(vmd.time_from.getHours())
        d.setMinutes(vmd.time_from.getMinutes())
      }
      params['utc_min'] = Math.floor(d.getTime() / 1000)
    }
    
    if (vmd.date_to != null) {
      var d = new Date(vmd.date_to.getFullYear(), vmd.date_to.getMonth(), vmd.date_to.getDate())
      if (vmd.time_to != null) {
        d.setHours(vmd.time_to.getHours())
        d.setMinutes(vmd.time_to.getMinutes())
      }
      params['utc_max'] = Math.floor(d.getTime() / 1000)
    }
    
    if (vmd.level_min != null) params['level_min'] = vmd.level_min
    if (vmd.level_max != null) params['level_max'] = vmd.level_max
    
    ApiReq('admin_statistics2_get', params, ([ok, data]) => {
      
      panel.setLoading(false)
      
      if (ok != 'OK')
        return Ext.Msg.alert('Ошибка формирования статистики', `admin_statistics2_get: ${ok}`)
      
      if (data.err != null)
        switch (data.err) {
          default: return Ext.Msg.alert('Ошибка', JSON.stringify(data))
        }
      
      var s = Ext.data.StoreManager.lookup('MyStat2Store')
      s.setData(data.data)
      
    })
    
    
  },
  
})






Ext.create('Ext.data.Store', {
  storeId: 'MyStatStore',
  fields:['key', '1', '2', '3'],
  data: []
});

Ext.create('Ext.data.Store', {
  storeId: 'MyStat2Store',
  fields:['level', '1', '2', '3'],
  data: []
});




Ext.define('StatisticsWindow', {
  extend: 'Ext.window.Window',
  title: 'Статистика',
  maximized: false, maximizable: true, minimizable: false,
  monitorResize: true,
  closable: true,
  width: 800, height: 500,
  resizable: true,
  modal: false,
  padding: 0, bodyPadding: 0,
  liveDrag: true,
  layout: 'fit',
  
  viewModel: {
    data: {
      date_from: null,
      time_from: null,
      date_to: null,
      time_to: null,
    }
  },
  
  controller: 'MyStatisticsController',
  
  items: [
    {
      xtype: 'panel',
      reference: 'statisticsPanel',
      //region: 'center',
      bodyPadding: 0,
      padding: 10,
      border: false,
      region: 'center',
      layout: 'border',
      //height: '100%',
      //flex: 1,
      items: [
        {
          xtype: 'panel',
          layout: 'hbox',
          region: 'north',
          //collapsible: true,
          items: [
            {
              xtype: 'fieldset', title: 'Дата/время начала', items: [
                {xtype: 'datefield', format: 'd.m.Y', bind: '{date_from}'},
                {xtype: 'timefield', format: 'H:i', bind: '{time_from}'},
              ]
            },
            {
              xtype: 'fieldset', title: 'Дата/время окончания', items: [
                {xtype: 'datefield', format: 'd.m.Y', bind: '{date_to}'},
                {xtype: 'timefield', format: 'H:i', bind: '{time_to}'},
              ]
            },
          ],
        },
        
        {
          xtype: 'grid',
          //layout: 'fit',
          region: 'center',
          //height: '100%',
          store: Ext.data.StoreManager.lookup('MyStatStore'),
          columns: [
            {text: 'Key', dataIndex: 'key' },
            {text: 'Level1', dataIndex: '1'},
            {text: 'Level2', dataIndex: '2'},
            {text: 'Level3', dataIndex: '3'},
            {text: 'Level4', dataIndex: '4'},
            {text: 'Level5', dataIndex: '5'},
            {text: 'Level6', dataIndex: '6'},
            {text: 'Level7', dataIndex: '7'},
            {text: 'Level8', dataIndex: '8'},
            {text: 'Level9', dataIndex: '9'},
            {text: 'Level10', dataIndex: '10'},
            {text: 'Level11', dataIndex: '11'},
            {text: 'Level12', dataIndex: '12'},
            {text: 'Level13', dataIndex: '13'},
            {text: 'Level14', dataIndex: '14'},
          ],
        },
        
        {xtype: 'button', text: 'Сформировать', handler: 'onCalculateClick', region: 'south'},
        
      ],
    },
  ],
  
  listeners : {
    //'show': 'onShow',
    'close': 'onClose'
  }
  
})

Ext.define('Statistics2Window', {
  extend: 'Ext.window.Window',
  title: 'Статистика',
  maximized: false, maximizable: true, minimizable: false,
  monitorResize: true,
  closable: true,
  width: 800, height: 500,
  resizable: true,
  modal: false,
  padding: 0, bodyPadding: 0,
  liveDrag: true,
  layout: 'fit',
  
  viewModel: {
    data: {
      date_from: null,
      time_from: null,
      date_to: null,
      time_to: null,
      level_min: 1,
      level_max: 20,
    }
  },
  
  controller: 'MyStatistics2Controller',
  
  items: [
    {
      xtype: 'panel',
      reference: 'statistics2Panel',
      //region: 'center',
      bodyPadding: 0,
      padding: 0,
      border: false,
      region: 'center',
      layout: 'border',
      //height: '100%',
      //flex: 1,
      items: [
        {
          xtype: 'panel',
          layout: 'hbox',
          region: 'north',
          //collapsible: true,
          defaults: {margin: 5},
          items: [
            {
              xtype: 'fieldset', title: 'Дата/время начала', items: [
                {xtype: 'datefield', format: 'd.m.Y', bind: '{date_from}'},
                {xtype: 'timefield', format: 'H:i', bind: '{time_from}'},
              ]
            },
            {
              xtype: 'fieldset', title: 'Дата/время окончания', items: [
                {xtype: 'datefield', format: 'd.m.Y', bind: '{date_to}'},
                {xtype: 'timefield', format: 'H:i', bind: '{time_to}'},
              ]
            },
            {
              xtype: 'fieldset', title: 'Ограничения уровня', items: [
                {xtype: 'numberfield', fieldLabel: 'От', bind: '{level_min}'},
                {xtype: 'numberfield', fieldLabel: 'До', bind: '{level_max}'},
              ]
            },
          ],
        },
        
        {
          xtype: 'grid',
          //layout: 'fit',
          region: 'center',
          //height: '100%',
          store: Ext.data.StoreManager.lookup('MyStat2Store'),
          columns: [
            {text: 'Уровень', dataIndex: 'level'},
            {text: 'Входы', dataIndex: '01_enters_cnt'},
            {text: 'Поражения', dataIndex: '02_loses_cnt'},
            {text: 'Выходы', dataIndex: '03_leaves_cnt'},
            {text: 'Победы', dataIndex: '04_wins_cnt'},
            {text: 'Игроков на ур', dataIndex: '05_players_last_levels'},
            {text: 'Сред.счет победы', dataIndex: '07_wins_avg_score'},
            {text: 'win 1*', dataIndex: '08_wins_star1_pc'},
            {text: 'win 2*', dataIndex: '09_wins_star2_pc'},
            {text: 'win 3*', dataIndex: '10_wins_star3_pc'},
            {text: 'bonus1 всего', dataIndex: '13_bonus1buy_cnt'},
            {text: 'bonus1 сред', dataIndex: '14_bonus1buy_avg'},
            {text: 'bonus2 всего', dataIndex: '15_bonus2buy_cnt'},
            {text: 'bonus2 сред', dataIndex: '16_bonus2buy_avg'},
            {text: 'bonus3 всего', dataIndex: '17_bonus3buy_cnt'},
            {text: 'bonus3 сред', dataIndex: '18_bonus3buy_avg'},
            {text: 'шаров всего', dataIndex: '19_bubblebuy_cnt'},
            {text: 'шаров сред', dataIndex: '20_bubblebuy_avg'},
            {text: 'жизней всего', dataIndex: '21_lifebuy_cnt'},
            {text: 'жизней сред', dataIndex: '22_lifebuy_avg'},
            {text: 'fb подкл.', dataIndex: '23_bindfb_cnt'},
            {text: 'инвайтов', dataIndex: '24_invites_cnt'},
            {text: 'жищни отпр./получ.', dataIndex: '25_gotlife_cnt'},
            {text: 'revenue доход', dataIndex: '28_revenue'},
            {text: 'ARPU доход с игрока', dataIndex: '29_ARPU'}
          ],
        },
        
        {
          xtype: 'panel',
          region: 'south',
          items: [
            {xtype: 'button', margin: 5, text: 'Сформировать', handler: 'onCalculateClick'}
          ],
        },
        
      ],
    },
  ],
  
  listeners : {
    //'show': 'onShow',
    'close': 'onClose'
  }
  
})







Ext.define('Dashboard.Controller', {
  extend: 'Ext.app.ViewController',
  alias: 'controller.my_dashboard',
  
  init: function (view) {
    console.log(Ext.getClass(this).getName(), 'init')
  },
  
  onPlayersClick: function () {
    console.log(Ext.getClass(this).getName(), 'onPlayersClick')
    var w = Ext.create('PlayersWindow')
    w.show()
    opened_windows[w.id] = w
  },
  
  onStatisticsClick: function () {
    var w = Ext.create('StatisticsWindow')
    w.show()
    opened_windows[w.id] = w
  },
  
  onStatistics2Click: function () {
    var w = Ext.create('Statistics2Window')
    w.show()
    opened_windows[w.id] = w
  },
  
  onLogoutClick: function () {
    console.log('onLogoutClick')
    //ApiReq('admin_logout', {token: Ext.util.Cookies.get('admin_token')}, ([status, data]) => {})
    
    // close all opened windows
    for (w in opened_windows) opened_windows[w].close()
    opened_windows = {}
    
    ApiReq('admin_logout', {}, ([status, data]) => {})
    Ext.util.Cookies.clear('token')
    Ext.globalEvents.fireEvent('adminLoggedOut')
  },
  
})


Ext.define('Dashboard.View', {
  extend: 'Ext.container.Viewport',
  
  reference: 'dashboardView',
  
  viewModel: {
    data: {
      opened_windows: []
    }
  },
  
  controller: 'my_dashboard',
  
	items: [
    {
      xtype: 'panel',
      
      defaults: {
        xtype: 'button',
      },
      
      tbar: [
        {text: 'Игроки', handler: 'onPlayersClick'},
        {text: 'Статистика', handler: 'onStatisticsClick'},
        {text: 'Статистика2', handler: 'onStatistics2Click'},
        '->',
        {text: 'Выход', handler: 'onLogoutClick'},
      ],
    },
  ],
  
  beforeDestroy: function () {
    console.log(Ext.getClass(this).getName(), 'beforeDestroy')
  },
  onRemoved: function () {
    console.log(Ext.getClass(this).getName(), 'onRemoved')
  },
  
})