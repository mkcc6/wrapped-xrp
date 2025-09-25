const config = require('@layerzerolabs/solhint-config');

config.rules = {
    ...config.rules,
    'max-line-length': 'off',
};

module.exports = config;
