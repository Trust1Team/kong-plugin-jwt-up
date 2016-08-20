# JWT Upstream plugin for Kong
[![][t1t-logo]][Trust1Team-url]

Kong is a scalable, open source API Layer *(also known as an API Gateway, or
API Middleware)*. Kong was originally built at [Mashape][mashape-url] to
secure, manage and extend over [15,000 APIs &
Microservices](http://stackshare.io/mashape/how-mashape-manages-over-15000-apis-and-microservices)
for its API Marketplace, which generates billions of requests per month.

Backed by the battle-tested **NGINX** with a focus on high performance, Kong
was made available as an open-source platform in 2015. Under active
development, Kong is now used in production at hundreds of organizations from
startups, to large enterprises and government departments.

The JWT upstream plugin has been developed to provide a JWT towards upstream APIs - registered on Kong - without worrying about the authentication plugin used by a consumer.

More information can be found on the [jwt-up wiki page][jwt-up-doc]

[Website Trust1Team][Trust1Team-url]

[Website Kong][kong-url]

## Summary

Only works from Kong 0.8.0.
You can not use the JWT-up plugin in combination with the JWT plugin. This is because the JWT-up by default validates HS256 incoming JWT and implicitly generates a RS256 token for upstream APIs.
The JWT-up can be used in order to have 2 types of consumers:
- consumer applications, using a key-auth policy to reqeust a service
- end-user consumers, using a consumer application, in order to request a service

Both authentication means can be different:
- consumer applications: uses only key-auth
- end-user consumer: uses JWT received after successful login

Both will result - after applying the JWT-up - in a RS256 JWT - enriched - send to upstream API.

## Roadmap

Update to Kong 0.9.0
At the moment we need to provide the certificates hardcodes in the fixtures files. 
This is due to a cert upload issue we have using Kong 0.8.0

## Release Notes v1.4.0
Update JWT time to use ngx.time to be compliant with epoch spec.


## License

```
This file is part of the Trust1Team(R) sarl project.
 Copyright (c) 2014 Trust1Team sarl
 Authors: Trust1Team development

 
This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License version 3
 as published by the Free Software Foundation with the addition of the
 following permission added to Section 15 as permitted in Section 7(a):
 FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY Trust1T,
 Trust1T DISCLAIMS THE WARRANTY OF NON INFRINGEMENT OF THIRD PARTY RIGHTS.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.
 See the GNU Affero General Public License for more details.
 You should have received a copy of the GNU Affero General Public License
 along with this program; if not, see http://www.gnu.org/licenses or write to
 the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 Boston, MA, 02110-1301 USA.

 The interactive user interfaces in modified source and object code versions
 of this program must display Appropriate Legal Notices, as required under
 Section 5 of the GNU Affero General Public License.

 
You can be released from the requirements of the Affero General Public License
 by purchasing
 a commercial license. Buying such a license is mandatory if you wish to develop commercial activities involving the Trust1T software without
 disclosing the source code of your own applications.
 Examples of such activities include: offering paid services to customers as an ASP,
 Signing PDFs on the fly in a web application, shipping OCS with a closed
 source product...
Irrespective of your choice of license, the T1T logo as depicted below may not be removed from this file, or from any software or other product or service to which it is applied, without the express prior written permission of Trust1Team sarl. The T1T logo is an EU Registered Trademark (n° 12943131).
```

[kong-url]: https://getkong.org/
[Trust1Team-url]: http://trust1team.com
[t1t-logo]: http://imgur.com/lukAaxx.png
[jwt-up-doc]: https://trust1t.atlassian.net/wiki/pages/viewpage.action?pageId=74547210