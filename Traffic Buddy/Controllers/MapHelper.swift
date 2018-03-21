//
//  MapHelper.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 3/20/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import MapKit

class MapHelper {
    // draw a line from a starting point in a direction of specified length
    internal static func drawLine(start: CLLocation, direction: Double, length: Double) -> MKPolyline {
        var coords = [CLLocationCoordinate2D]()
        let startPoint = MKMapPointForCoordinate(start.coordinate)
        var point = MKMapPoint()
        
        point.x = startPoint.x + (length * sin(direction * Double.pi / 180))
        point.y = startPoint.y - (length * cos(direction * Double.pi / 180))
        
        coords.append(start.coordinate)
        coords.append(MKCoordinateForMapPoint(point))
        
        return MKPolyline(coordinates: coords, count: coords.count)
    }
    
    static func setupMapView(mapView: MKMapView, delegate: MKMapViewDelegate, markers: [Intersection]) {
        mapView.delegate = delegate
        mapView.layer.borderColor = UIColor.black.cgColor
        mapView.layer.borderWidth = 1.0
        
        for i in markers {
            // draw a circle to indicate intersection
            let circle = MKCircle(center: i.getLocation().coordinate, radius: 10 as CLLocationDistance)
            mapView.add(circle)
            
            for h in i.headings {
                // draw arrows to indicate heading directions
                let line = drawLine(start: i.getLocation(), direction: h, length: 250.0)
                mapView.add(line)
            }
        }
    }
    
    static func mapView(mapView: MKMapView, overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circle = MKCircleRenderer(overlay: overlay)
            circle.strokeColor = UIColor.red
            circle.fillColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.1)
            circle.lineWidth = 1
            return circle
        } else if overlay is MKPolyline {
            let line = MKPolylineRenderer(overlay: overlay)
            line.strokeColor = UIColor.red
            line.lineWidth = 2.0
            return line
        }
        return MKOverlayRenderer()
    }
    
    static let regionRadius: CLLocationDistance = 1000
    static func centerMapOnLocation(mapView: MKMapView, location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}
