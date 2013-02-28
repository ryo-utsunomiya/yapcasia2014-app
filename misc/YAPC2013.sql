
CREATE TABLE member (
    id CHAR(40) NOT NULL PRIMARY KEY,
    authenticated_by VARCHAR(255) NOT NULL,
    remote_id TEXT NOT NULL,
    name TEXT NOT NULL,
    nickname TEXT NOT NULL,
    email TEXT NOT NULL,
    created_on DATETIME NOT NULL,
    modified_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY ( authenticated_by, remote_id(255) ),
    KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET='utf8';


CREATE TABLE talk (
    id CHAR(4) NOT NULL PRIMARY KEY,
    status ENUM ( 'pending', 'accepted', 'rejected' ) NOT NULL DEFAULT 'pending',
    member_id CHAR(40) NOT NULL,
    venue_id INT,
    title TEXT,
    title_en TEXT,
    language ENUM ( 'ja', 'en' ) NOT NULL,
    subtitles ENUM ( 'none', 'ja', 'en' ) NOT NULL,
    category VARCHAR(255) NOT NULL,
    start_on DATETIME NOT NULL,
    duration ENUM ( 'LT', '20', '40' ) NOT NULL,
    material_level ENUM ('advanced', 'regular', 'beginner' ) NOT NULL DEFAULT 'regular',
    tags TEXT,
    tshirt_size ENUM( 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL' ),
    abstract TEXT NOT NULL,
    slide_url TEXT,
    video_url TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    calendar_entry_id TEXT,
    created_on DATETIME NOT NULL,
    modified_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES member (id),
    /* FOREIGN KEY (venue_id) REFERENCES venue (id), */
    KEY (status),
    KEY (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET='utf8';

CREATE TABLE notices_subscription_temp (
    id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    code CHAR(40) NOT NULL UNIQUE,
    email TEXT NOT NULL,
    expires_on DATETIME NOT NULL,
    created_on DATETIME NOT NULL,
    modified_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET='utf8';

CREATE TABLE notices_subscription (
    id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    email TEXT NOT NULL,
    created_on DATETIME NOT NULL,
    modified_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY(email(128))
) ENGINE=InnoDB DEFAULT CHARSET='utf8';
