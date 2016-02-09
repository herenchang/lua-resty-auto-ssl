local redis = require "resty.redis"

local _M = {}

local function get_redis_instance(self)
  local instance = ngx.ctx.auto_ssl_redis_instance
  if instance then
    return instance
  end

  instance = redis:new()
  local ok, err

  if self.options["socket"] then
    ok, err = instance:connect(self.options["socket"])
  else
    ok, err = instance:connect(self.options["host"], self.options["port"])
  end
  if not ok then
    return false, err
  end

  ngx.ctx.auto_ssl_redis_instance = instance
  return instance
end

function _M.new(auto_ssl_instance)
  local options = auto_ssl_instance:get("redis") or {}

  if not options["host"] then
    options["host"] = "127.0.0.1"
  end

  if not options["port"] then
    options["host"] = 6379
  end

  return setmetatable({ options = options }, { __index = _M })
end

function _M.setup()
end

function _M.get(self, key)
  local redis_instance, instance_err = get_redis_instance(self)
  if instance_err then
    return nil, instance_err
  end

  local res, err = redis_instance:get(key)
  if res == ngx.null then
    res = nil
    err = "not found"
  end

  return res, err
end

function _M.set(self, key, value, options)
  local redis_instance, instance_err = get_redis_instance(self)
  if instance_err then
    return false, instance_err
  end

  local ok, err = redis_instance:set(key, value)
  if ok then
    if options and options["exptime"] then
      local _, expire_err = redis_instance:expire(key, options["exptime"])
      if expire_err then
        ngx.log(ngx.ERR, "auto-ssl: failed to set expire: ", expire_err)
      end
    end
  end

  return ok, err
end

function _M.delete(self, key)
  local redis_instance, instance_err = get_redis_instance(self)
  if instance_err then
    return false, instance_err
  end

  return redis_instance:del(key)
end

return _M
