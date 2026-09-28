import 'dart:io';

import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/src/rust/api/qjs.dart';

void applyProxySetting(ProxySettingState setting) {
  final address = setting.address.trim();
  switch (setting.mode) {
    case ProxyMode.direct:
      setSocks5Proxy(proxy: '');
      SocksProxy.initProxy(proxy: 'DIRECT');
    case ProxyMode.system:
      setSocks5Proxy(proxy: '');
      SocksProxy.initProxy(findProxy: HttpClient.findProxyFromEnvironment);
    case ProxyMode.http:
      if (address.isEmpty) {
        applyProxySetting(const ProxySettingState(mode: ProxyMode.direct));
        return;
      }
      final proxyUrl =
          address.startsWith('http://') || address.startsWith('https://')
          ? address
          : 'http://$address';
      setHttpProxy(proxy: proxyUrl);
      SocksProxy.initProxy(proxy: 'PROXY ${stripProxyScheme(proxyUrl)}');
    case ProxyMode.socks5:
      if (address.isEmpty) {
        applyProxySetting(const ProxySettingState(mode: ProxyMode.direct));
        return;
      }
      setSocks5Proxy(proxy: address);
      SocksProxy.initProxy(proxy: 'SOCKS5 $address');
  }
}

String stripProxyScheme(String url) {
  var value = url.trim();
  for (final prefix in const ['https://', 'http://']) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
      break;
    }
  }
  return value;
}
