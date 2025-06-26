import 'package:webdav_client/src/acl_entry.dart';
import 'package:xml/xml.dart';

import 'file.dart';
import 'utils.dart';

const fileXmlStr = '''
    <d:propfind
        xmlns:d='DAV:'
        xmlns:oc='http://owncloud.org/ns'
        xmlns:nc='http://nextcloud.org/ns'>
			<d:prop>
				<d:displayname/>
				<d:resourcetype/>
				<d:getcontentlength/>
				<d:getcontenttype/>
				<d:getetag/>
				<d:getlastmodified/>
        <d:quota-used-bytes/>
        <oc:fileid />
        <nc:acl-list />
        <nc:acl-enabled />
			</d:prop>
		</d:propfind>''';

// const quotaXmlStr = '''<d:propfind xmlns:d="DAV:">
//            <d:prop>
//              <d:quota-available-bytes/>
//              <d:quota-used-bytes/>
//            </d:prop>
//          </d:propfind>''';

class WebdavXml {
  static List<XmlElement> findAllElements(XmlDocument document, String tag) =>
      document.findAllElements(tag, namespace: '*').toList();

  static List<XmlElement> findElements(XmlElement element, String tag) =>
      element.findElements(tag, namespace: '*').toList();

  static List<File> toFiles(String path, String xmlStr, {skipSelf = true}) {
    var files = <File>[];
    var xmlDocument = XmlDocument.parse(xmlStr);
    List<XmlElement> list = findAllElements(xmlDocument, 'response');
    // response
    list.forEach((element) {
      // name
      final hrefElements = findElements(element, 'href');
      String href = hrefElements.isNotEmpty ? hrefElements.single.text : '';

      // propstats
      var props = findElements(element, 'propstat');
      // propstat
      for (var propstat in props) {
        // ignore != 200
        if (findElements(propstat, 'status').single.text.contains('200')) {
          // prop
          for (var prop in findElements(propstat, 'prop')) {
            final resourceTypeElements = findElements(prop, 'resourcetype');
            // isDir
            bool isDir = resourceTypeElements.isNotEmpty
                ? findElements(resourceTypeElements.single, 'collection')
                    .isNotEmpty
                : false;

            // skip self
            if (skipSelf) {
              skipSelf = false;
              if (isDir) {
                break;
              }
              throw newXmlError('xml parse error(405)');
            }

            // fileId
            final fileIdElements = findElements(prop, 'fileid');
            int fileId = fileIdElements.isNotEmpty
                ? int.parse(fileIdElements.single.text)
                : 0;

            // mimeType
            final mimeTypeElements = findElements(prop, 'getcontenttype');
            String mimeType =
                mimeTypeElements.isNotEmpty ? mimeTypeElements.single.text : '';

            // size
            int size = 0;
            final sizeElements = findElements(
                prop, !isDir ? 'getcontentlength' : 'quota-used-bytes');
            size = sizeElements.isNotEmpty
                ? int.parse(sizeElements.single.text)
                : 0;

            // eTag
            final eTagElements = findElements(prop, 'getetag');
            String eTag =
                eTagElements.isNotEmpty ? eTagElements.single.text : '';

            // create time
            final cTimeElements = findElements(prop, 'creationdate');
            DateTime? cTime = cTimeElements.isNotEmpty
                ? DateTime.parse(cTimeElements.single.text).toLocal()
                : null;

            // modified time
            final mTimeElements = findElements(prop, 'getlastmodified');
            DateTime? mTime = mTimeElements.isNotEmpty
                ? str2LocalTime(mTimeElements.single.text)
                : null;

            // aclEnabled
            final aclEnabledElements = findElements(prop, 'acl-enabled');
            int aclEnabled = int.parse(aclEnabledElements.single.text);

            // aclList
            final aclListElements = findElements(prop, 'acl-list');
            List<AclEntry>? aclList;

            if (aclListElements.isNotEmpty) {
              aclList = [];
              final aclEntries = aclListElements.single;
              final aclElements = findElements(aclEntries, 'acl');

              for (var acl in aclElements) {
                final type =
                    findElements(acl, 'acl-mapping-type').singleOrNull?.text ??
                        '';
                final id =
                    findElements(acl, 'acl-mapping-id').singleOrNull?.text ??
                        '';
                final displayName =
                    findElements(acl, 'acl-mapping-display-name')
                            .singleOrNull
                            ?.text ??
                        '';
                final permissionsStr =
                    findElements(acl, 'acl-permissions').singleOrNull?.text ??
                        '0';

                int permissions = int.tryParse(permissionsStr) ?? 0;

                aclList.add(AclEntry(
                  type: type,
                  id: id,
                  displayName: displayName,
                  permissions: permissions,
                ));
              }
              print(aclList);
            }
            //
            var str = Uri.decodeFull(href);
            var name = path2Name(str);
            var filePath = path + name + (isDir ? '/' : '');

            files.add(File(
                fileId: fileId,
                path: filePath,
                isDir: isDir,
                name: name,
                mimeType: mimeType,
                size: size,
                eTag: eTag,
                cTime: cTime,
                mTime: mTime,
                aclEnabled: aclEnabled,
                aclList: aclList));
            break;
          }
        }
      }
    });
    return files;
  }
}
