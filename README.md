Ansible Role: Change SSL
=========

도메인을 사용하여 웹서버 작업시 필요한 정보를 알아냅니다.

Requirements
------------
None.

Role Variables
--------------
- `defaults/main.yml` 참조
```yaml
domain_name: ""
```

Dependencies
------------
None.

Example Playbook
----------------
- `test/` 참조
```yaml
- hosts: vms
  remote_user: root
  roles:
    - ansible.roles.web_conf_scout
```

License
------------
BSD