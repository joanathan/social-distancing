mapboxgl.accessToken = 'pk.eyJ1Ijoiam9hbmF0aGFuIiwiYSI6ImNrMjhqNTlqdjEyZGMzbW8wcnFlbmh0YjkifQ.LPxQZihnkDzrCEMxfStHhA';
let map, popup;

function initMap() {
  map = new mapboxgl.Map({
    container: 'map',
    center: [-122.465940, 37.761645],
    zoom: 11.9,
    style: 'mapbox://styles/mapbox/dark-v10'
  });

  popup = new mapboxgl.Popup({
    closeButton: false,
    closeOnClick: false
  });

  map.on('load', async () => {
    await setupMap()
    onMapLoad()
  })
}

async function setupMap() {
  // blockgroup source + layer
  map.addSource('blockgroup', {
    'type': 'geojson',
    'data': './geojson/sf_social_distancing.geojson',
    'generateId': true // need id to use feature state
  })
  map.addLayer({
    'id': 'blockgroup',
    'type': 'fill',
    'source': 'blockgroup',
    'paint': {
      'fill-color': [
        'interpolate',
        ['linear'],
        ['feature-state','distance_ft'],
          0, '#FE0404',
          6, '#FFBD06',
          12, '#fff306',
          18, '#00FFC2',
          24, '#0057FF'
        ],
      'fill-opacity': 0.4
    }
  })

  // transitline source + layer
  map.addSource('transitline', {
    'type': 'geojson',
    'data': './geojson/sf_muni_gtfs_shapes_line.geojson'
  })
  map.addLayer({
    'id': 'transitline',
    'type': 'line',
    'source': 'transitline',
    'layout': {
      'visibility': 'none',
      'line-join': 'round',
      'line-cap': 'round'
    },
    'paint': {
      'line-color': '#FFFFFF',
      'line-width': 0.3
    }
  })

  // transitline source + layer
  map.addSource('transitstop',  {
    'type': 'geojson',
    'data': './geojson/sf_muni_gtfs_stops.geojson'
  })
  map.addLayer({
    'id': 'transitstop',
    'type': 'symbol',
    'source': 'transitstop',
    'layout': {
      'visibility': 'none',
      'icon-image': 'bus',
      'icon-size': 0.5
    }
  })

  // hospital source + layer
  map.addSource('hospital',  {
    'type': 'geojson',
    'data': './geojson/sf_hospital.geojson'
  })
  map.addLayer({
    'id': 'hospital',
    'type': 'symbol',
    'source': 'hospital',
    'layout': {
      'visibility': 'none',
      'icon-image': 'hospital-11',
      'icon-size': 0.7
    }
  })

  // hospital source + layer
  map.addSource('foodservices',  {
    'type': 'geojson',
    'data': './geojson/sf_restaurant.geojson'
  })
  map.addLayer({
    'id': 'foodservices',
    'type': 'symbol',
    'source': 'foodservices',
    'layout': {
      'visibility': 'none',
      'icon-image': 'restaurant-15',
      'icon-size': 0.7
    }
  })

  map.on('mousemove', function(e) {
    onHover(e)
  });

  // on everything load, do stuff!
  map.on('idle', setAfterLoad);
  function setAfterLoad(e) {
    onMapReady();
    map.off('idle', setAfterLoad);
  }
}

function onHover(location) {
  let identifiedFeatures = map.queryRenderedFeatures(location.point, {
    layers: ['blockgroup']
  });

  if (identifiedFeatures.length !== 0) {
    map.getCanvas().style.cursor = 'pointer'
    showPopup(identifiedFeatures[0], location)
  } else {
    popup.remove();
    map.getCanvas().style.cursor = ''
  }
}

function showPopup(feature, location) {
  var layer = feature.layer.id
  var fields = fieldsToShow[layer]
  var popupsText = "";

  let properties = feature.properties
  let state = feature.state

  // calculate distance to show
  properties['distance_ft'] = state['distance_ft'] // copy feature state
  properties['rank_distance'] = rank(state['distance_ft'], [5, 18, 30])

  for (let key in properties) {
    if (properties[key] == "null") {
      properties[key] = 0;
    } else if (!isNaN(properties[key]) && properties[key].toString().includes('.')) {
      properties[key] = Math.round(properties[key] * 100)/100 // round to nearest hundredth
    } else if (key.includes('rank')) {
      properties[key] = `⭐`.repeat(properties[key])
    }
  }

  // write the fields
  for (i = 0; i < fields.length; i++) {
    if (fields[i].length == 1) {
      let title = getProperties(fields[i][0], properties)
      popupsText += `<div class='title'>${title}</div>`
    } else {
      let key = getProperties(fields[i][0], properties)
      let value = getProperties(fields[i][1], properties)
      popupsText += `<div class='section'>
                      <div class='bold'>${key}</div>
                      <div>${value}</div>
                    </div>`
    }

  };
  popup.setLngLat(location.lngLat)
  .setHTML(popupsText)
  .addTo(map);
}

function getProperties(template, properties) {
  return new Function("return `"+template +"`;").call(properties);
}

function calculateState(layer, state, process) {
  map.querySourceFeatures(layer).forEach(function(n) {
    map.setFeatureState({
      source: layer,
      id: n.id
    }, {
      [state]: process(n.properties)
    });
  });
}

function setVisibility(layer, toggleId) {
  if (map) {
    map.setLayoutProperty(layer, 'visibility', document.getElementById(toggleId).checked ? 'visible' : 'none');
  }
}

function rank(value, array) {
  for (let i = 0; i < array.length; i++) {
    if (value < array[i]) {
      return i
    }
  }
  return array.length
}
