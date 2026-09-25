const bikaSourceId = 'bika';
const ehSourceId = 'eh';

const nativeSourceIds = <String>{bikaSourceId, ehSourceId};

bool isNativeSourceId(String from) => nativeSourceIds.contains(from.trim());
