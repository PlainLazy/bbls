console.log('+ApiReq')


ApiReq = function (cm, params, handler) {
  
  var proto = /http(s?):/.test(location.protocol) ? '//' : 'http://'
  
  // https://docs.sencha.com/extjs/6.2.0/classic/Ext.Ajax.html
  return Ext.Ajax.request({
    
    //url: `${proto}apps.blissgame.org/api/${cm}`,
    url: `${proto}${location.host}/api/${cm}`,
    params: JSON.stringify(params),
    method: 'POST',
    disableCaching: false,
    withCredentials: true,  // with cookies
    
    callback: (opts, success, resp) => {
      console.log('ApiReq callback', opts, success, resp)
      
      if (success) {
        
        //console.log('ApiReq.success', resp)
        let status = resp.statusText
        let data
        if (status == 'OK') {
          try {
            data = JSON.parse(resp.responseText)
          } catch (e) {
            status = 'invalid json'
          }
        }
        Ext.isFunction(handler) && handler([status, data])
        
      } else {
        
        Ext.isFunction(handler) && handler([resp.statusText, null])
        
      }
      
    }
    
  })
  
}