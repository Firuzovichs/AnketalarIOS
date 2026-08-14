import SwiftUI
import CoreLocation
import UIKit

#if canImport(YandexMapsMobile)
import YandexMapsMobile

/// Yandex MapKit'ni o'rab turuvchi SwiftUI komponent.
/// Odamlarni pin sifatida chiqaradi, foydalanuvchi xaritani surganda
/// (gesture) markazni qayta o'rnatmaydi — faqat dasturiy (`centerOverride`)
/// markazlashtirish (GPS topilganda) uchun ishlatiladi.
struct YandexMapView: UIViewRepresentable {
    @Binding var centerOverride: CLLocationCoordinate2D?
    var users: [DashUser]
    var viewerIsVip: Bool
    var onRegionChanged: (CLLocationCoordinate2D) -> Void
    var onPinTap: (DashUser) -> Void

    private static let tashkentFallback = CLLocationCoordinate2D(latitude: 41.311081, longitude: 69.240562)

    func makeUIView(context: Context) -> YMKMapView {
        guard let mapView = YMKMapView(frame: .zero) else {
            fatalError("YMKMapView yaratilmadi: Yandex MapKit API kalit sozlanmaganmi?")
        }
        let map = mapView.mapWindow.map
        map.addCameraListener(with: context.coordinator)
        context.coordinator.mapView = mapView

        // O'z joylashuvini xaritada doimiy ko'rsatadigan ("ko'k nuqta") qatlam
        let userLocationLayer = YMKMapKit.sharedInstance().createUserLocationLayer(with: mapView.mapWindow)
        userLocationLayer.setVisibleWithOn(true)
        userLocationLayer.isHeadingModeActive = true
        userLocationLayer.setObjectListenerWith(context.coordinator)
        context.coordinator.userLocationLayer = userLocationLayer

        let target = centerOverride ?? Self.tashkentFallback
        map.move(with: YMKCameraPosition(
            target: YMKPoint(latitude: target.latitude, longitude: target.longitude),
            zoom: 13, azimuth: 0, tilt: 0
        ))
        context.coordinator.lastAppliedCenter = target
        return mapView
    }

    func updateUIView(_ uiView: YMKMapView, context: Context) {
        let map = uiView.mapWindow.map

        // Dasturiy markazlashtirish — faqat foydalanuvchi xaritani hali surmagan bo'lsa
        if let override = centerOverride, !context.coordinator.userHasPanned {
            let last = context.coordinator.lastAppliedCenter
            let moved = last == nil
                || abs(last!.latitude - override.latitude) > 0.0005
                || abs(last!.longitude - override.longitude) > 0.0005
            if moved {
                map.move(
                    with: YMKCameraPosition(
                        target: YMKPoint(latitude: override.latitude, longitude: override.longitude),
                        zoom: 14, azimuth: 0, tilt: 0
                    ),
                    animation: YMKAnimation(type: .smooth, duration: 0.4),
                    cameraCallback: nil
                )
                context.coordinator.lastAppliedCenter = override
            }
        }

        context.coordinator.syncPlacemarks(users: users, viewerIsVip: viewerIsVip, onTap: onPinTap)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRegionChanged: onRegionChanged)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, YMKMapCameraListener, YMKMapObjectTapListener, YMKUserLocationObjectListener {
        weak var mapView: YMKMapView?
        var lastAppliedCenter: CLLocationCoordinate2D?
        var userHasPanned = false
        var userLocationLayer: YMKUserLocationLayer?

        private let onRegionChanged: (CLLocationCoordinate2D) -> Void
        private var onTap: ((DashUser) -> Void)?
        private var usersById: [Int: DashUser] = [:]
        private var placemarks: [Int: YMKPlacemarkMapObject] = [:]
        private var renderedBlurState: [Int: Bool] = [:]

        /// Pin ostida chiqadigan ism yozuvi uslubi — ko'rsatkichdan pastda,
        /// oq konturli qora matn (xaritaning har xil fonida o'qilishi uchun).
        private static let nameTextStyle = YMKTextStyle(
            size: 11,
            color: .black,
            outlineWidth: 1.5,
            outlineColor: .white,
            placement: .bottom,
            offset: 4,
            offsetFromIcon: true,
            textOptional: false
        )

        // O'zining joylashuv belgisi (ko'k nuqta/o'q) — bosilganda xaritani shu nuqtaga markazlaydi
        private weak var userArrowObject: YMKMapObject?
        private weak var userPinObject: YMKMapObject?
        private var lastUserLocation: YMKPoint?

        init(onRegionChanged: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onRegionChanged = onRegionChanged
        }

        func onCameraPositionChanged(
            with map: YMKMap,
            cameraPosition: YMKCameraPosition,
            cameraUpdateReason: YMKCameraUpdateReason,
            finished: Bool
        ) {
            guard finished, cameraUpdateReason == .gestures else { return }
            userHasPanned = true
            let t = cameraPosition.target
            onRegionChanged(CLLocationCoordinate2D(latitude: t.latitude, longitude: t.longitude))
        }

        func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
            // O'zining joylashuv belgisi (arrow/pin) bosildi — xaritani o'sha nuqtaga markazlaymiz
            if mapObject === userArrowObject || mapObject === userPinObject {
                guard let mapView, let target = lastUserLocation else { return false }
                mapView.mapWindow.map.move(
                    with: YMKCameraPosition(target: target, zoom: 15, azimuth: 0, tilt: 0),
                    animation: YMKAnimation(type: .smooth, duration: 0.4),
                    cameraCallback: nil
                )
                return true
            }

            guard let placemark = mapObject as? YMKPlacemarkMapObject,
                  let userId = placemark.userData as? Int,
                  let user = usersById[userId] else { return false }
            onTap?(user)
            return true
        }

        // MARK: - YMKUserLocationObjectListener

        func onObjectAdded(with view: YMKUserLocationView) {
            view.arrow.addTapListener(with: self)
            view.pin.addTapListener(with: self)
            userArrowObject = view.arrow
            userPinObject = view.pin
            lastUserLocation = view.pin.geometry
        }

        func onObjectRemoved(with view: YMKUserLocationView) {}

        func onObjectUpdated(with view: YMKUserLocationView, event: YMKObjectEvent) {
            lastUserLocation = view.pin.geometry
        }

        func syncPlacemarks(users: [DashUser], viewerIsVip: Bool, onTap: @escaping (DashUser) -> Void) {
            self.onTap = onTap
            guard let mapView else { return }
            let mapObjects = mapView.mapWindow.map.mapObjects

            var newIds = Set<Int>()
            for user in users {
                guard let coord = user.coordinate else { continue }
                newIds.insert(user.id)
                usersById[user.id] = user

                if let existing = placemarks[user.id] {
                    // isValid — native ob'ekt hali tirikmi?
                    if existing.isValid {
                        existing.geometry = YMKPoint(latitude: coord.latitude, longitude: coord.longitude)
                    } else {
                        // Native ob'ekt eskirgan — eski yozuvni o'chirib qayta yaratamiz
                        placemarks.removeValue(forKey: user.id)
                        renderedBlurState.removeValue(forKey: user.id)
                        let placemark = mapObjects.addPlacemark()
                        placemark.geometry = YMKPoint(latitude: coord.latitude, longitude: coord.longitude)
                        placemark.userData = user.id
                        placemark.setIconWith(MapPinRenderer.placeholder(isOnline: user.is_online == true))
                        placemark.setTextWithText(user.mapLabel, style: Coordinator.nameTextStyle)
                        placemark.addTapListener(with: self)
                        placemarks[user.id] = placemark
                    }
                } else {
                    let placemark = mapObjects.addPlacemark()
                    placemark.geometry = YMKPoint(latitude: coord.latitude, longitude: coord.longitude)
                    placemark.userData = user.id
                    placemark.setIconWith(MapPinRenderer.placeholder(isOnline: user.is_online == true))
                    placemark.setTextWithText(user.mapLabel, style: Coordinator.nameTextStyle)
                    placemark.addTapListener(with: self)
                    placemarks[user.id] = placemark
                }

                loadPinImage(for: user, viewerIsVip: viewerIsVip)
            }

            // Endi ko'rinmaydigan (filtr/radius tashqarisidagi) odamlarning pin'larini olib tashlash
            for (id, placemark) in placemarks where !newIds.contains(id) {
                if placemark.isValid {
                    mapObjects.remove(with: placemark)
                }
                placemarks.removeValue(forKey: id)
                renderedBlurState.removeValue(forKey: id)
            }
        }

        private func loadPinImage(for user: DashUser, viewerIsVip: Bool) {
            let shouldBlur = !viewerIsVip
            if renderedBlurState[user.id] == shouldBlur { return }
            guard let url = user.photoURL else { return }
            renderedBlurState[user.id] = shouldBlur

            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let img = UIImage(data: data) else { return }
                let pin = MapPinRenderer.render(
                    image: img, blurred: shouldBlur,
                    isOnline: user.is_online == true, isVip: user.isPremium
                )
                DispatchQueue.main.async {
                    // isValid tekshirish — async callback kelguncha placemark o'chirilgan bo'lishi mumkin
                    guard let placemark = self.placemarks[user.id], placemark.isValid else { return }
                    placemark.setIconWith(pin)
                }
            }.resume()
        }
    }
}

#else

/// Yandex MapKit SPM paketi (`https://github.com/yandex/mapkit-ios`) hali qo'shilmagan —
/// shu zaxira ekran ko'rsatiladi. Paket qo'shilib, API kalit `YandexMapConfig.apiKey`
/// ga yozilgandan so'ng yuqoridagi haqiqiy xarita avtomatik ishga tushadi.
struct YandexMapView: View {
    @Binding var centerOverride: CLLocationCoordinate2D?
    var users: [DashUser]
    var viewerIsVip: Bool
    var onRegionChanged: (CLLocationCoordinate2D) -> Void
    var onPinTap: (DashUser) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.5))
            Text("Yandex MapKit SPM paketi ulanmagan")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Text("Xcode → Add Package Dependency → yandex/mapkit-ios")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}

#endif
