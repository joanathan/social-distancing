var fieldsToShow = {
  'blockgroup': [
    ["Block Group ${this.geoid10}"],
    ["Population 2019", "${this.population_2019} people"],
    ["Per Person Distance ${this.rank_distance}", "${this.distance_ft} feet"],
    ["Hospital ${this.rank_hospitaldistance}", "${this.hospital_name} (${this.hospital_distance_miles} miles)"],
    ["Food Services ${this.rank_foodservices}", "${this.count_foodservices} restaurants in the area"],
    ["Transit ${this.rank_munistops}", "${this.count_munistops} Muni stops nearby"]]
}

var toggleLayers = {
  'Hospital': {
    show: false,
    layers: ['hospital']
  },
  'Food Services': {
    show: false,
    layers: ['foodservices']
  },
  'Muni': {
    show: false,
    layers: ['transitline', 'transitstop']
  }
}

var pop_ratio;

function init() {
  // set up toggle options
  let toggles = ''
  for (let key in toggleLayers) {
    toggles += `<div><input type="checkbox" id="${key}" value="${key}" ${toggleLayers[key].show ? 'checked' : ''}> ${key}</div>`
  }
  document.getElementById('toggles').innerHTML = toggles

  initMap()
}

function setupEventListeners() {
  // event listeners
  // checkbox
  for (let key in toggleLayers) {
    for (let i = 0; i < toggleLayers[key].layers.length; i++) {
      document.getElementById(key).addEventListener('change', () => {setVisibility(toggleLayers[key].layers[i], key)})
    }
  }

  // sliders
  document.getElementById('slider').addEventListener('input', function(e) {
    updateDistance()
    document.getElementById('out-ratio').innerText = (pop_ratio * 100) + '%';
  });

}

function onMapLoad() {
  // any map specific but not layer / data specific things to do
}

function onMapReady() {
  setupEventListeners()
  for (let key in toggleLayers) {
    for (let i = 0; i < toggleLayers[key].layers.length; i++) {
      setVisibility(toggleLayers[key].layers[i], key)
    }
  }

  updateDistance()
}

function updateDistance() {
  pop_ratio = parseFloat(document.getElementById('slider').value)
  calculateState('blockgroup', 'distance_ft', (props) => {
    return Math.round(Math.sqrt(props['sidewalk_area'] / (props['population_2019'] * pop_ratio)))
  })
}

init()
