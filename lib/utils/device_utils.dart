// BlueSnafer Pro - Device Utilities
// Shared OUI lookup, name resolution, and device type detection

/// Known Bluetooth OUI prefixes (first 6 hex chars of MAC address)
/// Note: Each OUI appears only once. Shared OUIs are assigned to the most likely manufacturer.
const Map<String, String> kKnownOUIs = {
  // ==================== APPLE ====================
  '00054F': 'APPLE', '000D4B': 'APPLE', '0010FA': 'APPLE', '0016CB': 'APPLE',
  '0017F2': 'APPLE', '00184A': 'APPLE', '0019E3': 'APPLE', '001A51': 'APPLE',
  '001B63': 'APPLE', '001C42': 'APPLE', '001E52': 'APPLE', '001F5B': 'APPLE',
  '0021E9': 'APPLE', '002241': 'APPLE', '002312': 'APPLE', '002332': 'APPLE',
  '00236C': 'APPLE', '0023DF': 'APPLE', '002500': 'APPLE', '00254B': 'APPLE',
  '002608': 'APPLE', '0026B0': 'APPLE', '0026BB': 'APPLE', '008865': 'APPLE',
  '0C74C2': 'APPLE', '109ADD': 'APPLE', '1040F3': 'APPLE', '186590': 'APPLE',
  '20C9D0': 'APPLE', '30E171': 'APPLE', '34363B': 'APPLE', '40A6A4': 'APPLE',
  '44D884': 'APPLE', '4C3275': 'APPLE', '50B7F0': 'APPLE', '5CC8D5': 'APPLE',
  '600308': 'APPLE', '685B35': 'APPLE', '6C96CF': 'APPLE', '705681': 'APPLE',
  '74E2F5': 'APPLE', '7831C1': 'APPLE', '784F43': 'APPLE', '78A3E4': 'APPLE',
  '7C11BE': 'APPLE', '80E650': 'APPLE', '843835': 'APPLE', '8863DF': 'APPLE',
  '9027E4': 'APPLE', '90840D': 'APPLE', '985AEB': 'APPLE', '98D6BB': 'APPLE',
  'A86632': 'APPLE', 'ACBC32': 'APPLE', 'B8098A': 'APPLE', 'B853AC': 'APPLE',
  'BCEE7B': 'APPLE', 'C09F42': 'APPLE', 'C86F1D': 'APPLE', 'CC29F5': 'APPLE',
  'D0034B': 'APPLE', 'D4862E': 'APPLE', 'D8A25E': 'APPLE', 'DCCA8C': 'APPLE',
  'E0553D': 'APPLE', 'E09996': 'APPLE', 'E425E9': 'APPLE', 'EC852F': 'APPLE',
  'F0B479': 'APPLE', 'F4F5DB': 'APPLE',

  // ==================== SAMSUNG ====================
  '0000F0': 'SAMSUNG', '0007AB': 'SAMSUNG', '000918': 'SAMSUNG', '001247': 'SAMSUNG',
  '001620': 'SAMSUNG', '0017C9': 'SAMSUNG', '0018AF': 'SAMSUNG', '001E7D': 'SAMSUNG',
  '00210D': 'SAMSUNG', '00221A': 'SAMSUNG', '002338': 'SAMSUNG', '002375': 'SAMSUNG',
  '0023C0': 'SAMSUNG', '002456': 'SAMSUNG', '00265E': 'SAMSUNG', '00268E': 'SAMSUNG',
  '0403D6': 'SAMSUNG', '0495E6': 'SAMSUNG', '082443': 'SAMSUNG', '0C8D98': 'SAMSUNG',
  '101D96': 'SAMSUNG', '145BD1': 'SAMSUNG', '184E94': 'SAMSUNG', '1C66AA': 'SAMSUNG',
  '244B03': 'SAMSUNG', '2C542D': 'SAMSUNG', '3C5A86': 'SAMSUNG', '4844F7': 'SAMSUNG',
  '5056A8': 'SAMSUNG', '544A05': 'SAMSUNG', '5C0A5B': 'SAMSUNG', '5C2E59': 'SAMSUNG',
  '641C67': 'SAMSUNG', '6C2F2C': 'SAMSUNG', '74563C': 'SAMSUNG', '782544': 'SAMSUNG',
  '7846D4': 'SAMSUNG', '807B3E': 'SAMSUNG', '8425DB': 'SAMSUNG', '88329B': 'SAMSUNG',
  '8C71F8': 'SAMSUNG', '908D78': 'SAMSUNG', '94350A': 'SAMSUNG', '9C8C6E': 'SAMSUNG',
  'A45D36': 'SAMSUNG', 'A82C6D': 'SAMSUNG', 'B09928': 'SAMSUNG', 'B4CE40': 'SAMSUNG',
  'B89A2A': 'SAMSUNG', 'BCF2AF': 'SAMSUNG', 'C81479': 'SAMSUNG', 'C85195': 'SAMSUNG',
  'CCF3A5': 'SAMSUNG', 'D45F25': 'SAMSUNG', 'D88039': 'SAMSUNG', 'E8EDF3': 'SAMSUNG',
  'F4F1E1': 'SAMSUNG',

  // ==================== GOOGLE ====================
  '001A11': 'GOOGLE', '001EDF': 'GOOGLE', '001FC6': 'GOOGLE', '00222E': 'GOOGLE',
  '04E676': 'GOOGLE', '10683F': 'GOOGLE', '188B45': 'GOOGLE', '204747': 'GOOGLE',
  '24FD5B': 'GOOGLE', '3C52A1': 'GOOGLE', '43474C': 'GOOGLE', '4C5DCD': 'GOOGLE',
  '546009': 'GOOGLE', '5CF8A1': 'GOOGLE', '68A0F6': 'GOOGLE', '749F3C': 'GOOGLE',
  '7CE524': 'GOOGLE', '88C397': 'GOOGLE', '98829C': 'GOOGLE', 'A098ED': 'GOOGLE',
  'AC3870': 'GOOGLE', 'B42A0E': 'GOOGLE', 'B8E625': 'GOOGLE', 'C04A00': 'GOOGLE',
  'D8B04C': 'GOOGLE', 'E0C79D': 'GOOGLE', 'E8EB1B': 'GOOGLE', 'FCA667': 'GOOGLE',

  // ==================== SONY ====================
  '00044B': 'SONY', '000A95': 'SONY', '001346': 'SONY', '00162C': 'SONY',
  '0019C1': 'SONY', '001B5A': 'SONY', '001D0D': 'SONY', '001F81': 'SONY',
  '00238E': 'SONY', '002643': 'SONY', '002789': 'SONY', '045D4B': 'SONY',
  '0C1420': 'SONY', '100000': 'SONY', '142E50': 'SONY', '1C9148': 'SONY',
  '24336C': 'SONY', '2C6A6F': 'SONY', '306CBE': 'SONY', '3C846A': 'SONY',
  '44E4D9': 'SONY', '544249': 'SONY', '5C9D96': 'SONY', '609ECF': 'SONY',
  '702605': 'SONY', '7884EE': 'SONY', '7C0BC0': 'SONY', '801F02': 'SONY',
  '884EA6': 'SONY', '8C541D': 'SONY', '9CA3BA': 'SONY', 'A0481C': 'SONY',
  'A8E621': 'SONY', 'C8BF96': 'SONY', 'DC2C63': 'SONY', 'E0F847': 'SONY',
  'E89C25': 'SONY', 'F0BF97': 'SONY', 'FC0FE6': 'SONY',

  // ==================== MICROSOFT ====================
  '000822': 'MICROSOFT', '000AF3': 'MICROSOFT', '0013D4': 'MICROSOFT', '0015A2': 'MICROSOFT',
  '001731': 'MICROSOFT', '0019CB': 'MICROSOFT', '0019DF': 'MICROSOFT', '001BFC': 'MICROSOFT',
  '001D72': 'MICROSOFT', '00216C': 'MICROSOFT', '002556': 'MICROSOFT', '0463EA': 'MICROSOFT',
  '0C3796': 'MICROSOFT', '100D7F': 'MICROSOFT', '148692': 'MICROSOFT', '188796': 'MICROSOFT',
  '281878': 'MICROSOFT', '30636B': 'MICROSOFT', '4437E6': 'MICROSOFT', '4886C8': 'MICROSOFT',
  '4C0B9E': 'MICROSOFT', '4C7897': 'MICROSOFT', '5076AF': 'MICROSOFT', '54E1AD': 'MICROSOFT',
  '5C1437': 'MICROSOFT', '646E97': 'MICROSOFT', '6854F5': 'MICROSOFT', '7427EA': 'MICROSOFT',
  '7C1E52': 'MICROSOFT', '80C16E': 'MICROSOFT', '845CF0': 'MICROSOFT', '8CBE9B': 'MICROSOFT',
  '90B11C': 'MICROSOFT', '94D9B3': 'MICROSOFT', '985FD3': 'MICROSOFT', '9C37F1': 'MICROSOFT',
  'A0999B': 'MICROSOFT', 'A823FE': 'MICROSOFT', 'B06EBF': 'MICROSOFT', 'B47C9C': 'MICROSOFT',
  'BCB1F3': 'MICROSOFT', 'C427CE': 'MICROSOFT', 'CC46D6': 'MICROSOFT', 'D0176A': 'MICROSOFT',
  'D4A97A': 'MICROSOFT', 'E09D31': 'MICROSOFT', 'E4CE8F': 'MICROSOFT', 'E8ABFA': 'MICROSOFT',
  'ECB3B1': 'MICROSOFT', 'F0DEF1': 'MICROSOFT', 'FC5065': 'MICROSOFT',

  // ==================== LG ====================
  '000B0D': 'LG', '001B5D': 'LG', '001E75': 'LG', '0022A9': 'LG',
  '002483': 'LG', '0838A5': 'LG', '0C24A1': 'LG', '283CE4': 'LG',
  '344DEA': 'LG', '3C9872': 'LG', '4073A5': 'LG', '4806BC': 'LG',
  '5C514F': 'LG', '648099': 'LG', '70D932': 'LG', '785DCE': 'LG',
  '8027EC': 'LG', '84A991': 'LG', '8C1F94': 'LG', '943CC6': 'LG',
  'A0AFB9': 'LG', 'A8B456': 'LG', 'AC5D10': 'LG', 'B0DDC2': 'LG',
  'B8BC1B': 'LG', 'BCE09D': 'LG', 'C808E9': 'LG', 'C86C87': 'LG',
  'CC33BB': 'LG', 'D4D184': 'LG', 'D86CE7': 'LG', 'E48D8C': 'LG',
  'E8F928': 'LG', 'F40F1B': 'LG', 'F80CF3': 'LG', 'FCDBB3': 'LG',

  // ==================== XIAOMI ====================
  'AC3743': 'XIAOMI', 'F40E07': 'XIAOMI', '04A151': 'XIAOMI', '102AB3': 'XIAOMI',
  '286C07': 'XIAOMI', '3482C5': 'XIAOMI', '38ADBE': 'XIAOMI', '40313C': 'XIAOMI',
  '50EC50': 'XIAOMI', '5C6B32': 'XIAOMI', '68DFDD': 'XIAOMI', '7C1D6C': 'XIAOMI',
  '8CFA45': 'XIAOMI', '902E87': 'XIAOMI', '98FAE3': 'XIAOMI', 'A46CB7': 'XIAOMI',
  'A865B2': 'XIAOMI', 'B0E235': 'XIAOMI', 'C40415': 'XIAOMI', 'C47C8D': 'XIAOMI',
  'D4970B': 'XIAOMI', 'E09467': 'XIAOMI', 'F0B4D3': 'XIAOMI', 'FC64BA': 'XIAOMI',

  // ==================== HUAWEI ====================
  '0013EF': 'HUAWEI', '002389': 'HUAWEI', '00259E': 'HUAWEI', '048C9A': 'HUAWEI',
  '087A4C': 'HUAWEI', '109FA9': 'HUAWEI', '147590': 'HUAWEI', '2008ED': 'HUAWEI',
  '2872C5': 'HUAWEI', '308730': 'HUAWEI', '346BD3': 'HUAWEI', '38C7BA': 'HUAWEI',
  '404D8E': 'HUAWEI', '486EF7': 'HUAWEI', '4CDB96': 'HUAWEI', '5078A3': 'HUAWEI',
  '548998': 'HUAWEI', '587BE9': 'HUAWEI', '607EC4': 'HUAWEI', '688F84': 'HUAWEI',
  '708BCD': 'HUAWEI', '7472F5': 'HUAWEI', '78A106': 'HUAWEI', '8038FD': 'HUAWEI',
  '84A06E': 'HUAWEI', '901B0E': 'HUAWEI', '9482A3': 'HUAWEI', '9C28EB': 'HUAWEI',
  'A02BB7': 'HUAWEI', 'A49981': 'HUAWEI', 'B09074': 'HUAWEI', 'B43052': 'HUAWEI',
  'B83D4E': 'HUAWEI', 'C8A048': 'HUAWEI', 'CC08FB': 'HUAWEI', 'D02DB3': 'HUAWEI',
  'E46C21': 'HUAWEI', 'E8CD2D': 'HUAWEI', 'EC233D': 'HUAWEI', 'F02572': 'HUAWEI',
  'F4559C': 'HUAWEI', 'F83DFF': 'HUAWEI',

  // ==================== BOSE (unique OUIs only) ====================
  '0007A0': 'BOSE', '0452C7': 'BOSE', '4CC96E': 'BOSE', 'B09A8A': 'BOSE',
  'C449BB': 'BOSE', 'D4016D': 'BOSE', 'E0E751': 'BOSE',

  // ==================== JBL / Harman (unique OUIs only) ====================
  '00043E': 'JBL', '000A3A': 'JBL', '000D44': 'JBL', '002215': 'JBL',
  '006465': 'JBL', '04DC0E': 'JBL', '08EB29': 'JBL', '102C6B': 'JBL',
  '2024E2': 'JBL', '40B4CD': 'JBL', '4C8E6F': 'JBL', '546C0E': 'JBL',
  '64B853': 'JBL', '70EA5A': 'JBL', '80E4DA': 'JBL', '88C663': 'JBL',
  '8CDE52': 'JBL', 'A4DD9E': 'JBL', 'B41489': 'JBL', 'B4C042': 'JBL',
  'CC8CE3': 'JBL', 'DCB7E9': 'JBL', 'E01877': 'JBL',

  // ==================== FITBIT (unique OUIs only) ====================
  '001653': 'FITBIT', '04EE03': 'FITBIT', '18B430': 'FITBIT', '28AE4D': 'FITBIT',
  '2DC873': 'FITBIT', '50934F': 'FITBIT', '644A50': 'FITBIT', '659B60': 'FITBIT',
  '712C2B': 'FITBIT', 'B07FB9': 'FITBIT', 'B4E62D': 'FITBIT', 'E74F0D': 'FITBIT',

  // ==================== GARMIN (unique OUIs only) ====================
  '000836': 'GARMIN', '00160D': 'GARMIN', '002377': 'GARMIN', '04A7DA': 'GARMIN',
  '080028': 'GARMIN', '146095': 'GARMIN', '200C60': 'GARMIN', '285979': 'GARMIN',
  '3029BE': 'GARMIN', '3C71BF': 'GARMIN', '409BC2': 'GARMIN', '48E533': 'GARMIN',
  '4C72B9': 'GARMIN', '54AF97': 'GARMIN', '5C4B82': 'GARMIN', '60D819': 'GARMIN',
  '7058A4': 'GARMIN', '786A89': 'GARMIN', '808F11': 'GARMIN', '8C9842': 'GARMIN',
  '9C79AC': 'GARMIN', 'A0A8CD': 'GARMIN', 'A4D931': 'GARMIN', 'AC0964': 'GARMIN',
  'B0C69A': 'GARMIN', 'B86761': 'GARMIN', 'D4775A': 'GARMIN', 'D82F6E': 'GARMIN',
  'E0AAB0': 'GARMIN', 'E8590D': 'GARMIN', 'F03A55': 'GARMIN', 'F4B164': 'GARMIN',
  'FCD0E7': 'GARMIN',
};

/// Strings that indicate a device name is not usable
const List<String> kUnknownNames = [
  '',
  'Unknown',
  'Unknown Device',
  'Unknown Bonded',
  'Unknown Classic',
  'Hidden',
  'N/A',
  'null',
];

/// Get manufacturer/vendor from MAC address OUI prefix
String getManufacturer(String address) {
  final cleanAddr = address.toUpperCase().replaceAll(':', '').replaceAll('-', '');
  if (cleanAddr.length < 6) return '';
  
  final oui = cleanAddr.substring(0, 6);
  return kKnownOUIs[oui] ?? '';
}

/// Check if a device name is usable (not empty/unknown)
bool isDeviceNameUsable(String? name) {
  if (name == null) return false;
  final trimmed = name.trim();
  return trimmed.isNotEmpty && !kUnknownNames.contains(trimmed);
}

/// Get display name for a device with proper fallback
/// Returns the actual name if available, otherwise a descriptive fallback
String getDeviceDisplayName(Map<String, dynamic> device) {
  final name = device['name']?.toString() ?? '';
  final address = device['address']?.toString() ?? '';

  // If we have a real name, use it
  if (isDeviceNameUsable(name)) {
    return name.toUpperCase();
  }

  // No name - use MAC address as identifier
  final shortAddr = address.length >= 8 ? address.substring(0, 8).toUpperCase() : address.toUpperCase();
  final vendor = getManufacturer(address);
  
  if (vendor.isNotEmpty) {
    return '$vendor [$shortAddr]';
  }
  
  // No vendor match - just show MAC address
  return 'DEVICE [$shortAddr]';
}

/// Detect device type from name and other characteristics
String detectDeviceType(Map<String, dynamic> device) {
  final name = (device['name'] ?? '').toString().toLowerCase();
  final address = (device['address'] ?? '').toString().toUpperCase();
  final isBeacon = device['isBeacon'] == true;
  
  // Name-based detection
  if (name.contains('iphone') || name.contains('ipad') || name.contains('ios')) {
    return 'smartphone';
  }
  if (name.contains('android') || name.contains('samsung') || name.contains('pixel') || name.contains('xiaomi') || name.contains('huawei')) {
    return 'smartphone';
  }
  if (name.contains('headset') || name.contains('headphone') || name.contains('earbud') || 
      name.contains('airpod') || name.contains('buds') || name.contains('audio') ||
      name.contains('speaker') || name.contains('sound') || name.contains('music') ||
      name.contains('bose') || name.contains('jbl') || name.contains('sony')) {
    return 'audio';
  }
  if (name.contains('car') || name.contains('vehicle') || name.contains('obd') || 
      name.contains('auto') || name.contains('dash')) {
    return 'car';
  }
  if (name.contains('watch') || name.contains('band') || name.contains('fit') || 
      name.contains('garmin') || name.contains('fitbit')) {
    return 'wearable';
  }
  if (name.contains('keyboard') || name.contains('mouse') || name.contains('trackpad') ||
      name.contains('pen') || name.contains('stylus')) {
    return 'peripheral';
  }
  
  // OUI-based detection
  final manufacturer = getManufacturer(address);
  if (manufacturer == 'APPLE' || manufacturer == 'SAMSUNG' || manufacturer == 'GOOGLE' ||
      manufacturer == 'XIAOMI' || manufacturer == 'HUAWEI') {
    return 'smartphone';
  }
  if (manufacturer == 'BOSE' || manufacturer == 'JBL') {
    return 'audio';
  }
  if (manufacturer == 'GARMIN' || manufacturer == 'FITBIT') {
    return 'wearable';
  }
  
  // Beacon detection
  if (isBeacon) return 'beacon';
  
  return 'unknown';
}

/// Get detailed device type with manufacturer info
String getDetailedDeviceType(Map<String, dynamic> device) {
  final type = detectDeviceType(device);
  final manufacturer = getManufacturer(device['address'] ?? '');
  
  switch (type) {
    case 'smartphone':
      return '$manufacturer PHONE';
    case 'audio':
      return manufacturer != 'GENERIC' ? '$manufacturer AUDIO' : 'AUDIO DEVICE';
    case 'car':
      return 'VEHICLE SYSTEM';
    case 'wearable':
      return manufacturer != 'GENERIC' ? '$manufacturer WEARABLE' : 'WEARABLE';
    case 'peripheral':
      return 'INPUT DEVICE';
    case 'beacon':
      return 'BLE BEACON';
    default:
      return manufacturer != 'GENERIC' ? '$manufacturer DEVICE' : 'UNKNOWN DEVICE';
  }
}
