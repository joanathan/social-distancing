var fieldsToShow = {
  'blockgroup': [
    ["Block Group ${this.geoid10}"],
    ["Population 2019", "${this.population_2019} people"],
    ["Per Person Distance ${this.rank_distance}", "${this.distance_ft} feet"],
    ["Hospital ${this.rank_hospitaldistance}", "${this.hospital_name} (${this.hospital_distance_miles} miles)"],
    ["Food Services ${this.rank_foodservices}", "${this.count_foodservices} restaurants in the area"],
    ["Transit ${this.rank_munistops}", "${this.count_munistops} Muni stops nearby"]]
}

var inputs = {
  'BlockGroups': {
    listeners: [{
      type: 'slider',
      id: 'slider',
      action: 'input',
      callback: updateDistance
    }],
    layers: ['blockgroup']
  },
  'Hospital': {
    listeners: [visibilityToggle(false)],
    layers: ['hospital'],
  },
  'Food Services': {
    listeners: [visibilityToggle(false)],
    layers: ['foodservices'],
  },
  'Muni': {
    listeners: [visibilityToggle(false)],
    layers: ['transitline', 'transitstop'],
  }
}
var layerToInput = {} // reverse lookup

function visibilityToggle(show) {
  return {
    type: 'toggle',
    show: show,
    action: 'change',
    callback: setLayersVisibility,
  }
}

function init() {
  let toggles = ''
  for (let key in inputs) {
    // set up toggle options
    for (let i = 0; i < inputs[key].listeners.length; i++) {
      if (inputs[key].listeners[i].type == 'toggle') {
        toggles += `<div><input type="checkbox" id="${key}" value="${key}" ${inputs[key].listeners[i].show ? 'checked' : ''}> ${key}</div>`
      }
    }
    // set up reverse lookup
    for (let i = 0; i < inputs[key].layers.length; i++) {
      layerToInput[inputs[key].layers[i]] = key
    }
  }
  document.getElementById('toggles').innerHTML = toggles

  initMap()
}

function onMapLoad() {
  // any map specific but not layer / data specific things to do
}

function onLayerLoad(layer) {
  let key = layerToInput[layer]
  if (key) {
    for (let i = 0; i < inputs[key].listeners.length; i++) {
      let listener = inputs[key].listeners[i]
      document.getElementById( listener.id ? listener.id : key).addEventListener(
        listener.action, () => {listener.callback(key)})
      listener.callback(key)
    }
  }
}

// event listener callbacks
function setLayersVisibility(key) {
  for (let i = 0; i < inputs[key].layers.length; i++) {
    setVisibility(inputs[key].layers[i], key)
  }
}

function updateDistance() {
  let pop_ratio = parseFloat(document.getElementById('slider').value)
  calculateState('blockgroup', 'distance_ft', (props) => {
    return Math.round(Math.sqrt(props['sidewalk_area'] / (props['population_2019'] * pop_ratio)))
  })
  document.getElementById('out-ratio').innerText = (pop_ratio * 100) + '%';
}

init()
