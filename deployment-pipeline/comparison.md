# Deployment Choices for Nia

## Introduction

Kijani Kiosk now has two demonstrated approaches for delivering and maintaining its payments service: blue/green deployment and container-based deployment managed by Kubernetes.

Blue/green deployment keeps two versions of the service available. One version handles customer traffic while the other can be prepared and tested. When the new version is ready, traffic is switched to it. If the new version fails, traffic can be returned to the previous version.

Container-based deployment packages the application and its runtime into a consistent unit. Kubernetes manages the running copies, monitors their availability and replaces copies that fail. These approaches solve related but different problems. Blue/green deployment controls how releases are introduced and reversed, while containers make applications easier to package, distribute and operate consistently.

## Comparison

| Concern | Blue/green approach | Container and Kubernetes approach |
|---|---|---|
| Deployment mechanism | Two application versions are maintained, with traffic directed to the active version. A controlled switch introduces the new release. | A versioned application image is deployed as two running copies managed by Kubernetes. |
| Rollback mechanism | Traffic is redirected to the previously working version when monitoring detects a failure. | A failed or unhealthy copy can be replaced with another instance of the deployed image. Returning to an older application version requires deploying that version. |
| Failure recovery | A monitoring script checks the application and can trigger a switch back to the previous environment. | Kubernetes maintains the declared number of application copies and replaces a deleted pod. |
| Scaling | Additional application capacity can be prepared, but traffic routing and capacity management need to be coordinated. | The desired number of application copies can be declared and managed centrally. Further scaling decisions still require capacity planning and appropriate configuration. |

## What the project measurements show

The blue/green rollback test provides a measurable recovery result. During a controlled failure test, the green environment was found unhealthy and traffic was returned to the working blue environment. The complete recovery took **65 seconds**, meeting the project's target of 90 seconds by 25 seconds. The service was then verified through its normal entry point, returning a successful health response from version 1.3.0.

The container and Kubernetes tests demonstrate a different recovery capability. The payments application was deployed as two running copies. One pod was deliberately deleted to simulate an instance failure. Kubernetes created a replacement and restored the two healthy copies in **32 seconds**. The test demonstrates automatic pod replacement; it does not represent a complete node-failure test or prove recovery from every possible application fault.

The application was also published to a private container registry and pulled back successfully. The final image measured approximately **109 MB**, compared with a 269 MB single-stage baseline. This represents a reduction of approximately **59.5%**, or 160 MB. The original image-size objective was below 100 MB. The final image exceeded that target by 9 MB, and the Technical Mentor approved the deviation. The smaller image is useful because it reduces the amount of data that must be stored and transferred when distributing the application.

The Kubernetes Service was verified through two access paths. Requests through the NodePort returned a successful health response, and an application pod also reached the service using its internal Kubernetes DNS name. Both checks returned HTTP 200. This confirms that the service was reachable externally through the configured node port and internally through Kubernetes service discovery.

## What each approach does not solve alone

Blue/green deployment provides a clear release and rollback mechanism, but it does not automatically guarantee that every application dependency, database change or customer transaction can be safely reversed. Those risks still require testing, monitoring and careful release planning.

Containers improve consistency and portability, but packaging an application does not by itself provide traffic switching, automatic recovery, secure secret management or a zero-downtime release strategy. Kubernetes adds orchestration capabilities such as maintaining the desired number of application copies and replacing deleted pods. However, the tests performed here do not establish automatic scaling under changing customer demand or recovery from a complete cluster failure.

## Recommendation

The evidence supports using both approaches together where appropriate. Containers provide a consistent way to package and distribute the payments application, while Kubernetes manages its running instances. Blue/green release practices can then provide a controlled way to introduce new versions and return to a known working release when necessary.

The measured results give the team useful starting points: a 65-second blue/green rollback, a 32-second Kubernetes pod replacement and a 59.5% reduction in image size. These results demonstrate specific capabilities under controlled test conditions; they should not be interpreted as guarantees for every production incident.

The next improvements should include testing application readiness during releases, validating database migration and rollback procedures, strengthening secret management, and conducting failure tests that include dependencies and infrastructure. Scaling should also be tested under realistic traffic before making claims about customer-load capacity.

In summary, blue/green deployment provides a controlled way to change and reverse releases. Containers and Kubernetes provide consistent packaging and automated instance management. Used together, they offer Kijani Kiosk a more complete deployment and recovery process than relying on either capability alone.